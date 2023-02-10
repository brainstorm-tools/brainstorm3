function varargout = process_ft_timelockstatistics( varargin )
% PROCESS_FT_TIMELOCKESTATISTICS Call FieldTrip function ft_timelockstatistics.
%
% Reference: http://www.fieldtriptoolbox.org/reference/ft_timelockstatistics

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
% Authors: Arnaud Gloaguen, Francois Tadel, 2015-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'FieldTrip: ft_timelockstatistics';
    sProcess.Category    = 'Stat2';
    sProcess.SubGroup    = 'Test';
    sProcess.Index       = 130;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Statistics';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data',  'matrix'};
    sProcess.OutputTypes = {'pdata', 'pmatrix'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 2;
    % Definition of the options
    sProcess = DefineStatOptions(sProcess);
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Get standard stat comment
    Comment = process_test_parametric2('FormatComment', sProcess);
    % Paired test
    if (sProcess.options.statistictype.Value == 2)
        Comment = strrep(Comment, 'unequal', 'paired');
    end
    % Get correction type
    strCorr = sProcess.options.correctiontype.Value{2}{sProcess.options.correctiontype.Value{1}};
    if ~strcmpi(strCorr, 'no')
        Comment = strrep(Comment, '[', [strCorr ' [']);
    end
    % Add tag for FieldTrip process
    Comment = ['FT ' Comment];
end


%% ===== DEFINE STATISTICS OPTIONS ======
function sProcess = DefineStatOptions(sProcess)
    % ===== INPUT OPTIONS =====
    sProcess.options.label1.Comment = '<B><U>Input options</U></B>:';
    sProcess.options.label1.Type    = 'label';
    % === SENSOR TYPES
    sProcess.options.sensortypes.Comment    = 'Sensor types (empty=all): ';
    sProcess.options.sensortypes.Type       = 'text';
    sProcess.options.sensortypes.Value      = 'EEG';
    sProcess.options.sensortypes.InputTypes = {'data'};
    % === TIME WINDOW ===
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % === SCOUTS SELECTION ===
    sProcess.options.scoutsel.Comment    = 'Use scouts';
    sProcess.options.scoutsel.Type       = 'scout_confirm';
    sProcess.options.scoutsel.Value      = {};
    sProcess.options.scoutsel.InputTypes = {'results'};
    % === SCOUT FUNCTION ===
    sProcess.options.scoutfunc.Comment   = {'Mean', 'PCA', 'All', 'Scout function:'};
    sProcess.options.scoutfunc.Type      = 'radio_line';
    sProcess.options.scoutfunc.Value     = 1;
    sProcess.options.scoutfunc.InputTypes = {'results'};
    % === ABSOLUTE VALUE
    sProcess.options.isabs.Comment    = 'Test absolute values';
    sProcess.options.isabs.Type       = 'checkbox';
    sProcess.options.isabs.Value      = 0;
    sProcess.options.isabs.Hidden     = 1;
    % === AVERAGE OVER TIME
    sProcess.options.avgtime.Comment    = 'Average over time';
    sProcess.options.avgtime.Type       = 'checkbox';
    sProcess.options.avgtime.Value      = 0;
    % === AVERAGE OVER CHANNELS
    sProcess.options.avgchan.Comment    = 'Average over channels';
    sProcess.options.avgchan.Type       = 'checkbox';
    sProcess.options.avgchan.Value      = 0;
    sProcess.options.avgchan.InputTypes = {'data', 'timefreq', 'matrix'};
    % === AVERAGE OVER FREQUENCY
    sProcess.options.avgfreq.Comment    = 'Average over frequency';
    sProcess.options.avgfreq.Type       = 'checkbox';
    sProcess.options.avgfreq.Value      = 0;
    sProcess.options.avgfreq.InputTypes = {'timefreq'};
    % === UNCONSTRAINED SOURCES
    sProcess.options.label_norm.Comment    = ['<FONT color="#777777">Note: For unconstrained sources, "absolute value" refers to the norm<BR>' ...
                                              'of the three orientations: abs(F) = sqrt(Fx^2 + Fy^2 + Fz^2).</FONT>'];
    sProcess.options.label_norm.Type       = 'label';
    sProcess.options.label_norm.InputTypes = {'results'};
    
    % ===== STATISTICAL TESTING OPTIONS =====
    sProcess.options.label2.Comment  = '<BR><B><U>Statistical testing (Monte-Carlo)</U></B>:';
    sProcess.options.label2.Type     = 'label';
    % === NUMBER OF RANDOMIZATIONS
    sProcess.options.randomizations.Comment = 'Number of randomizations:';
    sProcess.options.randomizations.Type    = 'value';
    sProcess.options.randomizations.Value   = {1000, '', 0};
    % === STATISTICS APPLIED FOR SAMPLES : TYPE
    % The statistic that is computed for each sample in each random reshuffling of the data
    sProcess.options.statistictype.Comment = {'Independent t-test', 'Paired t-test', ''};   % More options: See below 'statcfg.statistic'
    sProcess.options.statistictype.Type    = 'radio_line';
    sProcess.options.statistictype.Value   = 1;
    % === TAIL FOR THE TEST STATISTIC
    sProcess.options.tail.Comment  = {'One-tailed (-)', 'Two-tailed', 'One-tailed (+)', ''; ...
                                      'one-', 'two', 'one+', ''};
    sProcess.options.tail.Type     = 'radio_linelabel';
    sProcess.options.tail.Value    = 'two';
    
    % ===== MULTIPLE COMPARISONS OPTIONS =====
    sProcess.options.label3.Comment = '<BR><B><U>Correction for multiple comparisons</U></B>:';
    sProcess.options.label3.Type    = 'label';
    % === TYPE OF CORRECTION
    sProcess.options.correctiontype.Comment = 'Type of correction: ';   % More options: See below 'statcfg.correctm'
    sProcess.options.correctiontype.Type    = 'combobox';
    sProcess.options.correctiontype.Value   = {2, {'no', 'cluster', 'bonferroni', 'fdr', 'max', 'holm', 'hochberg', 'tfce'}};
%     % === WAY TO COMBINE SAMPLES OF A CLUSTER
%     % How to combine the single samples that belong to a cluster
%     % 'wcm' refers to 'weighted cluster mass', a statistic that combines cluster size and intensity; see Hayasaka & Nichols (2004) NeuroImage for details.
%     sProcess.options.clusterstatistic.Comment   = {'maxsum', 'maxsize', 'wcm', 'Cluster function: '};  
%     sProcess.options.clusterstatistic.Type      = 'radio_line';
%     sProcess.options.clusterstatistic.Value     = 1;    
    % === MINIMUM NUMBER OF NEIGHBOURING CHANNELS
    sProcess.options.minnbchan.Comment    = 'Min number of neighbours (minnbchan): ';
    sProcess.options.minnbchan.Type       = 'value';
    sProcess.options.minnbchan.Value      = {0, '', 0};
    sProcess.options.minnbchan.InputTypes = {'data', 'timefreq', 'results'};
    % === CLUSTER ALPHA VALUE
    sProcess.options.clusteralpha.Comment = 'Cluster Alpha :';
    sProcess.options.clusteralpha.Type    = 'value';
    sProcess.options.clusteralpha.Value   = {0.05, '', 4};
end


%% ===== GET STAT OPTIONS =====
function OPT = GetStatOptions(sProcess)
    % Input options
    if isfield(sProcess.options, 'sensortypes') && isfield(sProcess.options.sensortypes, 'Value')
        OPT.SensorTypes = sProcess.options.sensortypes.Value;
    end
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && ~isempty(sProcess.options.timewindow.Value)
        OPT.TimeWindow = sProcess.options.timewindow.Value{1};
    else
        OPT.TimeWindow = [];
    end
    OPT.isAvgTime   = sProcess.options.avgtime.Value;
    OPT.isAbsolute  = sProcess.options.isabs.Value;
    if OPT.isAbsolute
        strAbs = ' abs';
    else
        strAbs = '';
    end
    if isfield(sProcess.options, 'avgchan') && isfield(sProcess.options.avgchan, 'Value')
        OPT.isAvgChan = sProcess.options.avgchan.Value;
    end
    if isfield(sProcess.options, 'avgfreq') && isfield(sProcess.options.avgfreq, 'Value')
        OPT.isAvgFreq = sProcess.options.avgfreq.Value;
    end
    % Scouts
    if isfield(sProcess.options, 'scoutsel') && isfield(sProcess.options.scoutsel, 'Value') && isfield(sProcess.options, 'scoutfunc') && isfield(sProcess.options.scoutfunc, 'Value')
        OPT.ScoutSel = sProcess.options.scoutsel.Value;
        switch (sProcess.options.scoutfunc.Value)
            case 1, OPT.ScoutFunc = 'mean';
            case 2, OPT.ScoutFunc = 'pca';
            case 3, OPT.ScoutFunc = 'all';
        end
    else
        OPT.ScoutSel = [];
        OPT.ScoutFunc = [];
    end
    % Test statistic options
    switch (sProcess.options.statistictype.Value)
        case 1,  OPT.StatisticType  = 'indepsamplesT';  strType = '';
        case 2,  OPT.StatisticType  = 'depsamplesT';    strType = ' paired';
    end
    switch (sProcess.options.tail.Value)
        case {1, 'one-'},  OPT.Tail = -1;   % One-sided (negative)
        case {2, 'two'},   OPT.Tail = 0;    % Two-sided
        case {3, 'one+'},  OPT.Tail = 1;    % One-sided (positive)
    end
    % Cluster statistic options
    OPT.Randomizations     = sProcess.options.randomizations.Value{1};
    OPT.ClusterAlphaValue  = sProcess.options.clusteralpha.Value{1};
    switch (sProcess.options.correctiontype.Value{1})
        case 1,  OPT.Correction = 'no';          strCorrection = ' [uncorrected]';
        case 2,  OPT.Correction = 'cluster';     strCorrection = ' [cluster]';
        case 3,  OPT.Correction = 'bonferroni';  strCorrection = ' [bonferroni]';
        case 4,  OPT.Correction = 'fdr';         strCorrection = ' [fdr]';
        case 5,  OPT.Correction = 'max';         strCorrection = ' [max]';
        case 6,  OPT.Correction = 'holm';        strCorrection = ' [holm]';
        case 7,  OPT.Correction = 'hochberg';    strCorrection = ' [hochberg]';
        case 8,  OPT.Correction = 'tfce';        strCorrection = ' [tfce]';
    end
    if isfield(sProcess.options, 'clusterstatistic') && isfield(sProcess.options.clusterstatistic, 'Value') && ~isempty(sProcess.options.clusterstatistic.Value)
        switch (sProcess.options.clusterstatistic.Value)
            case 1,  OPT.ClusterStatistic = 'maxsum';
            case 2,  OPT.ClusterStatistic = 'maxsize';
            case 3,  OPT.ClusterStatistic = 'wcm';
        end
    else
        OPT.ClusterStatistic = 'maxsum';
    end
    % Neighborhood
    if isfield(sProcess.options, 'minnbchan') && isfield(sProcess.options.minnbchan, 'Value') && iscell(sProcess.options.minnbchan.Value) && ~isempty(sProcess.options.minnbchan.Value)
        OPT.MinNbChan = sProcess.options.minnbchan.Value{1};
    end
end


%% ===== RUN =====
function sOutput = Run(sProcess, sInputsA, sInputsB) %#ok<DEFNU>
    % Initialize returned variable 
    sOutput = [];
    % Initialize FieldTrip
    [isInstalled, errMsg] = bst_plugin('Install', 'fieldtrip');
    if ~isInstalled
        bst_report('Error', sProcess, [], errMsg);
        return;
    end
    bst_plugin('SetProgressLogo', 'fieldtrip');
    
    % ===== CHECK INPUTS =====
    % Make sure that file type is indentical for both sets
    if ~isempty(sInputsA) && ~isempty(sInputsB) && ~strcmpi(sInputsA(1).FileType, sInputsB(1).FileType)
        bst_report('Error', sProcess, sInputsA, 'Cannot process inputs from different types.');
        return;
    end
    % Check the number of files in input
    if (length(sInputsA) < 2) || (length(sInputsB) < 2)
        bst_report('Error', sProcess, sInputsA, 'Not enough files in input.');
        return;
    end
    
    % ===== GET OPTIONS =====
    OPT = GetStatOptions(sProcess);
    % Number of files
    nFilesA = length(sInputsA);
    nFilesB = length(sInputsB);
    % Check number of files
    if (nFilesA ~= nFilesB) && strcmpi(OPT.StatisticType, 'depsamplesT')
        bst_report('Error', sProcess, [], 'For a paired t-test, the number of files must be the same in the two groups.');
        return;
    end

    % ===== CHANNEL PROCESSING =====
    isMatrix = strcmpi(sInputsA(1).FileType, 'matrix');
    if ~isMatrix
        % ===== LOAD INPUT CHANNEL FILES =====
        bst_progress('text', 'Reading channel files...');
        % Get all the channel files involved
        uniqueChannelFiles = unique({sInputsA.ChannelFile, sInputsB.ChannelFile});
        % Load all the channel files
        AllChannelMats = cell(1, length(uniqueChannelFiles));
        for i = 1:length(uniqueChannelFiles)
            AllChannelMats{i} = in_bst_channel(uniqueChannelFiles{i});
            % Make sure that the list of sensors is the same
            if (i > 1) && ~isequal({AllChannelMats{1}.Channel.Name}, {AllChannelMats{i}.Channel.Name})
                bst_report('Error', sProcess, sInputsA, ['The list of channels in all the input files do not match.' 10 'Run the process "Standardize > Uniform list of channels" first.']);
                return;
            end
        end

        % ===== OUTPUT CHANNEL FILE =====
        % Get output channel study
        iOutputStudy = sProcess.options.iOutputStudy;
        [sChannel, iChanStudy] = bst_get('ChannelForStudy', iOutputStudy);
        % If there is one channel already existing: use it
        if ~isempty(sChannel)
            OutChannelMat = in_bst_channel(sChannel.FileName);
            % Make sure that the list of sensors is the same
            if ~isequal({OutChannelMat.Channel.Name}, {AllChannelMats{1}.Channel.Name})
                bst_report('Error', sProcess, sInputsA, ['The list of channels in the input files does not match the output channel file:' 10 sChannel.FileName]);
                return;
            end
        % Else: Compute an average of all the channel files
        else 
            % Compute average
            OutChannelMat = channel_average(AllChannelMats);
            % Save new channel file
            db_set_channel(iOutputStudy, OutChannelMat, 0, 0);
        end

        % ===== SENSOR SELECTION =====
        % Find sensors by names/types
        iChannelsOut = channel_find(OutChannelMat.Channel, OPT.SensorTypes);
        if isempty(iChannelsOut)
            bst_report('Error', sProcess, sInputsA, ['Channels "' OPT.SensorTypes '" not found in output channel file.']);
            return;
        end
        % Check that only one type of channels is selected
        ChannelTypes = unique({OutChannelMat.Channel(iChannelsOut).Type});
        if (length(ChannelTypes) > 1)
            bst_report('Error', sProcess, sInputsA, ['Multiple channel types in input: ' sprintf('%s ', ChannelTypes{:}), 10 'Cluster-based statistics can be applied on one type of sensors at a time.']);
            return;
        end
        % Keep only the channels that are good in all the trials (remove all the bad channels from all the trials)
        for i = 1:nFilesA
            DataMatA     = in_bst_data(sInputsA(i).FileName, 'ChannelFlag');
            iChannelsOut = setdiff(iChannelsOut, find(DataMatA.ChannelFlag == -1));
        end
        for i = 1:nFilesB
            DataMatB     = in_bst_data(sInputsB(i).FileName, 'ChannelFlag');
            iChannelsOut = setdiff(iChannelsOut, find(DataMatB.ChannelFlag == -1));
        end
        % Make sure that there are some sensors available
        if (length(ChannelTypes) > 1)
            bst_report('Error', sProcess, sInputsA, 'All the selected sensors are bad in at least one input file.');
            return;
        end
    else
        iChannelsOut = [];
    end
    
    % ===== CREATE FIELDTRIP STRUCTURES =====
    % Load all the files in the same structure
    sAllInputs = [sInputsA, sInputsB];
    ftAllFiles = cell(1, length(sAllInputs));
    for i = 1:length(sAllInputs)
        bst_progress('text', sprintf('Reading input files... [%d/%d]', i, length(sAllInputs)));
        % Convert file to a FieldTrip structure
        if isMatrix
            [ftAllFiles{i}, DataMat] = out_fieldtrip_matrix(sAllInputs(i).FileName);
        else
            [ftAllFiles{i}, DataMat] = out_fieldtrip_data(sAllInputs(i).FileName, sAllInputs(i).ChannelFile, iChannelsOut, 1);
        end
        % Time selection
        if ~isempty(OPT.TimeWindow)
            iTime = panel_time('GetTimeIndices', DataMat.Time, OPT.TimeWindow);
            ftAllFiles{i}.avg  = ftAllFiles{i}.avg(:, iTime);
            ftAllFiles{i}.time = ftAllFiles{i}.time(iTime);
        end
        % Save time vector for output
        if (i == 1)
            if (length(DataMat.Time) == 1)
                sfreq = 1000;
            else
                sfreq = 1/(DataMat.Time(2) - DataMat.Time(1));
            end
            OutTime = ftAllFiles{i}.time;
            if (length(OutTime) == 1)
                OutTime = OutTime + [0, 1/sfreq];
            end
        end
        % Absolue value
        if OPT.isAbsolute
            ftAllFiles{i}.avg = abs(ftAllFiles{i}.avg);
        end
        % Time average
        if OPT.isAvgTime
        	ftAllFiles{i}.avg  = mean(ftAllFiles{i}.avg, 2);
            ftAllFiles{i}.time = ftAllFiles{i}.time(1);
            if (i == 1)
                OutTime = OutTime([1,end]);
            end
        end
        % Channel average
        if OPT.isAvgChan && (size(ftAllFiles{i}.avg,1) > 1)
            ftAllFiles{i}.avg   = mean(ftAllFiles{i}.avg, 1);
            ftAllFiles{i}.label = {'avgchan'};
        end
        % Save first time vector
        if (i == 1)
            if isMatrix
                nChannels = size(DataMat.Value,1);
                iChannelsOut = 1:nChannels;
            else
                nChannels = length(OutChannelMat.Channel);
            end
        elseif ~isequal(size(ftAllFiles{i}.avg,1), size(ftAllFiles{1}.avg,1))
            bst_report('Error', sProcess, [], sprintf('All the files must have the same number of channels.\nFile #%d has %d channels, file #%d has %d channels.', 1, size(ftAllFiles{1}.avg,1), i, size(ftAllFiles{i}.avg,1)));
            return;
        elseif ~isequal(size(ftAllFiles{i}.avg,2), size(ftAllFiles{1}.avg,2))
            bst_report('Error', sProcess, [], sprintf('All the files must have the same number of time samples.\nFile #%d has %d samples, file #%d has %d samples.', 1, size(ftAllFiles{1}.avg,2), i, size(ftAllFiles{i}.avg,2)));
            return;
        elseif (abs(ftAllFiles{1}.time(1) - ftAllFiles{i}.time(1)) > 1e-6) % && (size(ftAllFiles{i}.avg,2) > 1)
            bst_report('Error', sProcess, [], 'The time definitions of the input files do not match.');
            return;
        end
    end
    
    % ===== CALL FIELDTRIP =====
    bst_progress('text', 'Calling FieldTrip function: ft_timelockstatistics...');
    % Input options
    statcfg = struct();
    statcfg.channel      = 'all'; % Channel selection already done so equal to 'all'
    statcfg.latency      = 'all'; % Time selection already done so equal to 'all'
    statcfg.avgovertime  = 'no';  % Time average already done so equal to 'no'
    statcfg.avgchan      = 'no';  % Space average already done so equal to 'no'

    % Different methods for calculating the significance probability and/or critical value
    %   cfg.method     = 'montecarlo'    get Monte-Carlo estimates of the significance probabilities and/or critical values from the permutation distribution
    %                    'analytic'      get significance probabilities and/or critical values from the analytic reference distribution (typically, the sampling distribution under the null hypothesis),
    %                    'stats'         use a parametric test from the MATLAB statistics toolbox,
    %                    'crossvalidate' use crossvalidation to compute predictive performance
    statcfg.method            = 'montecarlo';
    statcfg.numrandomization  = OPT.Randomizations;
     
    % Possible statistics to applied for each samples:
    %   cfg.statistic       = 'indepsamplesT'           independent samples T-statistic,
    %                         'indepsamplesF'           independent samples F-statistic,
    %                         'indepsamplesregrT'       independent samples regression coefficient T-statistic,
    %                         'indepsamplesZcoh'        independent samples Z-statistic for coherence,
    %                         'depsamplesT'             dependent samples T-statistic,
    %                         'depsamplesFmultivariate' dependent samples F-statistic MANOVA,
    %                         'depsamplesregrT'         dependent samples regression coefficient T-statistic,
    %                         'actvsblT'                activation versus baseline T-statistic.
    statcfg.statistic    = OPT.StatisticType;   
    statcfg.tail         = OPT.Tail;
    statcfg.correcttail  = 'prob';
    statcfg.parameter    = 'avg';    % parameter in FieldTrip structure on which the stats will be applied
    
    % Define the design of the experiment
    switch (OPT.StatisticType)
        case 'indepsamplesT'
            statcfg.design      = zeros(1, nFilesA + nFilesB);
            statcfg.design(1,:) = [ones(1,nFilesA), 2*ones(1,nFilesB)];
            statcfg.ivar        = 1;   % the one and only row in cfg.design contains the independent variable
        case 'depsamplesT'
            statcfg.design      = zeros(2, nFilesA + nFilesB);
            statcfg.design(1,:) = [ones(1,nFilesA), 2*ones(1,nFilesB)];
            statcfg.design(2,:) = [1:nFilesA 1:nFilesB];
            statcfg.ivar        = 1;   % the 1st row in cfg.design contains the independent variable
            statcfg.uvar        = 2;   % the 2nd row in cfg.design contains the subject number (or trial number)
    end
    
    % Multiple-comparison correction
    statcfg.correctm = OPT.Correction;
    % Additional parameters for the method
    switch (OPT.Correction)
        case 'no'
        case {'cluster', 'tfce'}
            % Define parameters for cluster statistics
            statcfg.clusteralpha     = OPT.ClusterAlphaValue;
            statcfg.clustertail      = statcfg.tail;
            statcfg.clusterstatistic = OPT.ClusterStatistic;
            % Number of neighbors to create a cluster
            if isfield(OPT, 'MinNbChan')
                statcfg.minnbchan = OPT.MinNbChan;
            end
            % Get neighbours
            if isMatrix
                statcfg.neighbours = [];
            else
                statcfg.neighbours = channel_neighbours(OutChannelMat, iChannelsOut);
            end
        case 'bonferroni'
        case 'fdr'
        case 'max'
        case 'holm'
        case 'hochberg'
    end

    % Main function that will compute the statistics
    ftStat = ft_timelockstatistics(statcfg, ftAllFiles{:});
    % Error management
    if ~isfield(ftStat, 'prob') || ~isfield(ftStat, 'stat') || isempty(ftStat.prob) || isempty(ftStat.stat)
        bst_report('Error', sProcess, [], 'Unknown error: The function ft_timelockstatistics did not return anything.');
        return;
    end
    % Apply thresholded mask on the p-values (the prob map is already thresholded for clusters)
    if ~ismember(OPT.Correction, {'no', 'cluster', 'tfce'})
        ftStat.prob(~ftStat.mask) = .999;
    end
    % Replace NaN values with zeros
    ftStat.stat(isnan(ftStat.stat)) = 0;
    
    % ===== CHANNEL ORDER =====
    if ~isMatrix
        % Check if at the end you still have the list of channel you want to keep and if they are in the same order
        if ~OPT.isAvgChan
            % Channel names to save in the file
            ChannelNames = {OutChannelMat.Channel(iChannelsOut).Name};
            % Check that the number of output signals is ok
            if length(ChannelNames) ~= length(ftStat.label)
                bst_report('Error', sProcess, [], 'Unknown problem with the output channels...');
                return;
            end
            % If the channels were re-ordered: fix it
            if ~isequal(ChannelNames', ftStat.label)
                % Find the corresponding channels in both lists
                [tmp, iFieltrip, iBrainstorm] = intersect(ftStat.label, ChannelNames);
                % Re-order all the matrices
                stat_tmp = ftStat;
                ftStat.stat(iBrainstorm, :)     = stat_tmp.stat(iFieltrip, :);
                ftStat.prob(iBrainstorm, :)     = stat_tmp.prob(iFieltrip, :);
                ftStat.label(iBrainstorm, :)    = stat_tmp.label(iFieltrip, :);
                if isfield(ftStat, 'posclusters') && ~isempty(ftStat.posclusters)
                    ftStat.posclusterslabelmat(iBrainstorm, :) = stat_tmp.posclusterslabelmat(iFieltrip, :);
                end
                if isfield(ftStat, 'negclusters') && ~isempty(ftStat.negclusters)
                    ftStat.negclusterslabelmat(iBrainstorm, :) = stat_tmp.negclusterslabelmat(iFieltrip, :);
                end
            end
        else
            ftStat.stat = repmat(ftStat.stat, length(iChannelsOut), 1);
            ftStat.prob = repmat(ftStat.prob, length(iChannelsOut), 1);
        end
    end
    
    % ===== OUTPUT STRUCTURE =====
    sOutput = db_template('statmat');
    % Store t- and p-values
    sOutput.tmap = zeros(nChannels, length(ftStat.time));
    sOutput.pmap = ones(nChannels, length(ftStat.time));
    sOutput.tmap(iChannelsOut,:) = ftStat.stat;
    sOutput.pmap(iChannelsOut,:) = ftStat.prob;
    % Output channel flag
    if ~isMatrix
        sOutput.ChannelFlag  = -1 * ones(nChannels,1);
        sOutput.ChannelFlag(iChannelsOut) = 1;
    else
        sOutput.Description = ftStat.label;
    end
    % Store other stuff
    sOutput.df            = [];
    sOutput.Correction    = OPT.Correction;
    sOutput.ColormapType  = 'stat2';
    sOutput.DisplayUnits  = 't';
    % Save clusters
    if isfield(ftStat, 'posclusters')
        sOutput.StatClusters.posclusters         = ftStat.posclusters;
        sOutput.StatClusters.posdistribution     = ftStat.posdistribution;
        sOutput.StatClusters.posclusterslabelmat = zeros(nChannels, length(ftStat.time));
        sOutput.StatClusters.posclusterslabelmat(iChannelsOut,:) = ftStat.posclusterslabelmat;
    end
    if isfield(ftStat, 'negclusters')
        sOutput.StatClusters.negclusters         = ftStat.negclusters;
        sOutput.StatClusters.negdistribution     = ftStat.negdistribution;
        sOutput.StatClusters.negclusterslabelmat = zeros(nChannels, length(ftStat.time));
        sOutput.StatClusters.negclusterslabelmat(iChannelsOut,:) = ftStat.negclusterslabelmat;
    end
    % Time: If there is only one time point, replicate to have two
    if (length(ftStat.time) == 1)
        sOutput.Time = [OutTime(1), OutTime(end)];
        sOutput.tmap = [sOutput.tmap(:,1), sOutput.tmap(:,1)];
        sOutput.pmap = [sOutput.pmap(:,1), sOutput.pmap(:,1)];
        if isfield(ftStat, 'posclusterslabelmat') && ~isempty(ftStat.posclusterslabelmat)
            sOutput.StatClusters.posclusterslabelmat = [sOutput.StatClusters.posclusterslabelmat(:,1), sOutput.StatClusters.posclusterslabelmat(:,1)];
        end
        if isfield(ftStat, 'negclusterslabelmat') && ~isempty(ftStat.negclusterslabelmat)
            sOutput.StatClusters.negclusterslabelmat = [sOutput.StatClusters.negclusterslabelmat(:,1), sOutput.StatClusters.negclusterslabelmat(:,1)];
        end
    else
        sOutput.Time = ftStat.time;
    end
    % Save FieldTrip configuration structure
    sOutput.cfg = statcfg;
    if isfield(sOutput.cfg, 'neighbours')
        sOutput.cfg = rmfield(sOutput.cfg, 'neighbours');
    end
    if isfield(ftStat, 'cfg') && isfield(ftStat.cfg, 'version')
        sOutput.cfg.version = ftStat.cfg.version;
    end
    % Save options
    sOutput.Options = OPT;
    % Last message
    bst_progress('text', 'Saving results...');
    bst_plugin('SetProgressLogo', []);
end




