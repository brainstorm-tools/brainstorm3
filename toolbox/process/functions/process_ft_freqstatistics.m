function varargout = process_ft_freqstatistics( varargin )
% PROCESS_FT_FREQSTATISTICS Call FieldTrip function ft_freqstatistics.
%
% Reference: http://www.fieldtriptoolbox.org/reference/ft_freqstatistics

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
% Authors: Arnaud Gloaguen, Francois Tadel, 2015-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'FieldTrip: ft_freqstatistics';
    sProcess.Category    = 'Stat2';
    sProcess.SubGroup    = 'Test';
    sProcess.Index       = 132;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Statistics';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq'};
    sProcess.OutputTypes = {'ptimefreq'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 2;
    sProcess.isSeparator = 1;
    % Definition of the options
    sProcess = process_ft_timelockstatistics('DefineStatOptions', sProcess);
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = process_ft_timelockstatistics('FormatComment', sProcess);
end


%% ===== RUN =====
function sOutput = Run(sProcess, sInputsA, sInputsB) %#ok<DEFNU>
    % Initialize returned variable 
    sOutput = [];
    % Initialize fieldtrip
    bst_ft_init();
    
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
    OPT = process_ft_timelockstatistics('GetStatOptions', sProcess);
    % Number of files
    nFilesA = length(sInputsA);
    nFilesB = length(sInputsB);
    % Check number of files
    if (nFilesA ~= nFilesB) && strcmpi(OPT.StatisticType, 'depsamplesT')
        bst_report('Error', sProcess, [], 'For a paired t-test, the number of files must be the same in the two groups.');
        return;
    end

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
            bst_report('Warning', sProcess, sInputsA, ['The list of channels in all the input files do not match.' 10 ...
                'You will not be able to display topography plots of the sensor values.' 10 ...
                'If you need this feature, run the process "Standardize > Uniform list of channels" first.']);
            AllChannelMats = [];
            break;
        end
    end

    % ===== OUTPUT CHANNEL FILE =====
    if ~isempty(AllChannelMats)
        % Get output channel study
        iOutputStudy = sProcess.options.iOutputStudy;
        [sChannel, iChanStudy] = bst_get('ChannelForStudy', iOutputStudy);
        % If there is one channel already existing: use it
        if ~isempty(sChannel)
            OutChannelMat = in_bst_channel(sChannel.FileName);
            % Make sure that the list of sensors is the same
            if ~isequal({OutChannelMat.Channel.Name}, {AllChannelMats{1}.Channel.Name})
                bst_report('Warning', sProcess, sInputsA, ['The list of channels in the input files does not match the output channel file:' 10 sChannel.FileName]);
            end
        % Else: Compute an average of all the channel files
        else 
            % Compute average
            OutChannelMat = channel_average(AllChannelMats);
            % Save new channel file
            db_set_channel(iOutputStudy, OutChannelMat, 0, 0);
        end
    end
    
    % ===== CREATE FIELDTRIP STRUCTURES =====
    % Load all the files in the same structure
    sAllInputs = [sInputsA, sInputsB];
    ftAllFiles = cell(1, length(sAllInputs));
    neighbours = [];
    for i = 1:length(sAllInputs)
        bst_progress('text', sprintf('Reading input files... [%d/%d]', i, length(sAllInputs)));
        % Convert file to a FieldTrip structure
        if (i == 1)
            [ftAllFiles{i}, TimefreqMat, neighbours] = out_fieldtrip_timefreq(sAllInputs(i).FileName, sAllInputs(i).ChannelFile);
        else
            [ftAllFiles{i}, TimefreqMat] = out_fieldtrip_timefreq(sAllInputs(i).FileName, sAllInputs(i).ChannelFile);
        end
        % Time selection
        if ~isempty(OPT.TimeWindow) && (size(ftAllFiles{i}.powspctrm,2) > 1)
            iTime = panel_time('GetTimeIndices', TimefreqMat.Time, OPT.TimeWindow);
            ftAllFiles{i}.powspctrm = ftAllFiles{i}.powspctrm(:,iTime,:);
            ftAllFiles{i}.time      = ftAllFiles{i}.time(iTime);
            if ~isempty(TimefreqMat.TFmask)
                TimefreqMat.TFmask = TimefreqMat.TFmask(:,iTime);
            end
        end
        % Save time vector for output
        if (i == 1)
            if (length(TimefreqMat.Time) == 1)
                sfreq = 1000;
            else
                sfreq = 1/(TimefreqMat.Time(2) - TimefreqMat.Time(1));
            end
            OutTime = ftAllFiles{i}.time;
            if (length(OutTime) == 1)
                OutTime = OutTime + [0, 1/sfreq];
            end
            TFmask = TimefreqMat.TFmask;
        % Following files
        else
            % Combine TFmasks
            if ~isempty(TFmask) && isequal(size(TFmask), size(TimefreqMat.TFmask))
                TFmask = TFmask & TimefreqMat.TFmask;
            end
        end
        % Absolue value
        if OPT.isAbsolute
            ftAllFiles{i}.powspctrm = abs(ftAllFiles{i}.powspctrm);
        end
        % Channel average
        if OPT.isAvgChan && (size(ftAllFiles{i}.powspctrm,1) > 1)
            ftAllFiles{i}.powspctrm = mean(ftAllFiles{i}.powspctrm, 1);
            ftAllFiles{i}.label     = {'avgchan'};
        end
        % Time average
        if OPT.isAvgTime && (size(ftAllFiles{i}.powspctrm,2) > 1)
        	ftAllFiles{i}.powspctrm = mean(ftAllFiles{i}.powspctrm, 2);
            ftAllFiles{i}.time      = ftAllFiles{i}.time(1);
            if (i == 1)
                OutTime = OutTime([1,end]);
            end
        end
        % Frequency average
        if OPT.isAvgFreq && (size(ftAllFiles{i}.powspctrm,3) > 1)
            ftAllFiles{i}.powspctrm = mean(ftAllFiles{i}.powspctrm, 3);
            ftAllFiles{i}.freq      = ftAllFiles{i}.freq(1);
        end
        % Check time time vectors
        if (i == 1)
            % Nothing
        elseif ~isequal(size(ftAllFiles{i}.powspctrm,2), size(ftAllFiles{1}.powspctrm,2))
            bst_report('Error', sProcess, [], sprintf('All the files must have the same number of time samples.\nFile #%d has %d samples, file #%d has %d samples.', 1, size(ftAllFiles{1}.powspctrm,2), i, size(ftAllFiles{i}.powspctrm,2)));
            return;
        elseif ~isequal(size(ftAllFiles{i}.powspctrm,3), size(ftAllFiles{1}.powspctrm,3))
            bst_report('Error', sProcess, [], sprintf('All the files must have the same number of frequency bins.\nFile #%d has %d samples, file #%d has %d bins.', 1, size(ftAllFiles{1}.powspctrm,3), i, size(ftAllFiles{i}.powspctrm,3)));
            return;
%         elseif (abs(ftAllFiles{1}.freq(1) - ftAllFiles{i}.freq(1)) > 0)
%             bst_report('Error', sProcess, [], 'The frequency definitions of the input files do not match.');
%             return;
%         elseif (abs(ftAllFiles{1}.time(1) - ftAllFiles{i}.time(1)) > 1e-6)
%             bst_report('Error', sProcess, [], 'The time definitions of the input files do not match.');
%             return;
            % Only one time point: use the time of the first file
            elseif (length(ftAllFiles{i}.time) == 1)
                ftAllFiles{i}.time = ftAllFiles{1}.time;
        end
    end
    
    % ===== CALL FIELDTRIP =====
    bst_progress('text', 'Calling FieldTrip function: ft_freqstatistics...');
    % Input options
    statcfg = struct();
    statcfg.channel            = 'all'; % Channel selection already done so equal to 'all'
    statcfg.latency            = 'all'; % Time selection already done so equal to 'all'
    statcfg.frequency          = 'all'; % Frequency selection already done so equal to 'all'
    statcfg.avgovertime        = 'no';  % Time average already done so equal to 'no'
    statcfg.avgchan            = 'no';  % Space average already done so equal to 'no'
    statcfg.avgoverfreq        = 'no';  % Frequency average already done so equal to 'no'

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
    statcfg.parameter    = 'powspctrm';    % parameter in FieldTrip structure on which the stats will be applied
    
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
        case 'cluster'
            % Define parameters for cluster statistics
            statcfg.clusteralpha     = OPT.ClusterAlphaValue;
            statcfg.clustertail      = statcfg.tail;
            statcfg.minnbchan        = OPT.MinNbChan;
            statcfg.clusterstatistic = OPT.ClusterStatistic;
            statcfg.neighbours       = neighbours;
        case 'bonferroni'
        case 'fdr'
        case 'max'
        case 'holm'
        case 'hochberg'
    end

    % Main function that will compute the statistics
    ftStat = ft_freqstatistics(statcfg, ftAllFiles{:});
    % Error management
    if ~isfield(ftStat, 'prob') || ~isfield(ftStat, 'stat') || isempty(ftStat.prob) || isempty(ftStat.stat)
        bst_report('Error', sProcess, [], 'Unknown error: The function ft_freqstatistics did not return anything.');
        return;
    end
    % Apply thresholded mask on the p-values (the prob map is already thresholded for clusters)
    if ~ismember(OPT.Correction, {'no', 'cluster'})
        ftStat.prob(~ftStat.mask) = .999;
    end
    % Replace NaN values with zeros
    ftStat.stat(isnan(ftStat.stat)) = 0;
    
    
    % ===== OUTPUT STRUCTURE =====
    sOutput = db_template('statmat');
    sOutput.tmap          = ftStat.stat;
    sOutput.pmap          = ftStat.prob;
    sOutput.RowNames      = ftStat.label;
    sOutput.df            = [];
    sOutput.Correction    = OPT.Correction;
    sOutput.ColormapType  = 'stat2';
    sOutput.DisplayUnits  = 't';
    sOutput.TFmask        = TFmask;
    
    % Save clusters
    if isfield(ftStat, 'posclusters')
        sOutput.StatClusters.posclusters         = ftStat.posclusters;
        sOutput.StatClusters.posdistribution     = ftStat.posdistribution;
        sOutput.StatClusters.posclusterslabelmat = ftStat.posclusterslabelmat;
    end
    if isfield(ftStat, 'negclusters')
        sOutput.StatClusters.negclusters         = ftStat.negclusters;
        sOutput.StatClusters.negdistribution     = ftStat.negdistribution;
        sOutput.StatClusters.negclusterslabelmat = ftStat.negclusterslabelmat;
    end
    % Time: If there is only one time point, replicate to have two
    if (length(ftStat.time) == 1)
        sOutput.Time = [OutTime(1), OutTime(end)];
        sOutput.tmap(:,2,:) = sOutput.tmap(:,1,:);
        sOutput.pmap(:,2,:) = sOutput.pmap(:,1,:);
        if isfield(ftStat, 'posclusterslabelmat') && ~isempty(ftStat.posclusterslabelmat)
            sOutput.StatClusters.posclusterslabelmat(:,2,:) = sOutput.StatClusters.posclusterslabelmat(:,1,:);
        end
        if isfield(ftStat, 'negclusterslabelmat') && ~isempty(ftStat.negclusterslabelmat)
            sOutput.StatClusters.negclusterslabelmat(:,2,:) = sOutput.StatClusters.negclusterslabelmat(:,1,:);
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
end




