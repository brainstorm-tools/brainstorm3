function varargout = process_ft_sourcestatistics( varargin )
% PROCESS_FT_SOURCESTATISTICS Call FieldTrip function ft_sourcestatistics.
%
% Reference: http://www.fieldtriptoolbox.org/reference/ft_sourcestatistics

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
    sProcess.Comment     = 'FieldTrip: ft_sourcestatistics';
    sProcess.Category    = 'Stat2';
    sProcess.SubGroup    = 'Test';
    sProcess.Index       = 131;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Statistics';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'results',  'timefreq'};
    sProcess.OutputTypes = {'presults', 'ptimefreq'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 2;
    % Definition of the options
    sProcess = process_ft_timelockstatistics('DefineStatOptions', sProcess);
    % Remove average channel option
    if isfield(sProcess.options, 'avgchan')
        sProcess.options = rmfield(sProcess.options, 'avgchan');
    end
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = process_ft_timelockstatistics('FormatComment', sProcess);
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
    OPT = process_ft_timelockstatistics('GetStatOptions', sProcess);
    % Number of files
    nFilesA = length(sInputsA);
    nFilesB = length(sInputsB);
    % Check number of files
    if (nFilesA ~= nFilesB) && strcmpi(OPT.StatisticType, 'depsamplesT')
        bst_report('Error', sProcess, [], 'For a paired t-test, the number of files must be the same in the two groups.');
        return;
    end

    % ===== CREATE FIELDTRIP STRUCTURES =====
    % Load all the files in the same structure
    sAllInputs = [sInputsA, sInputsB];
    ftAllFiles = cell(1, length(sAllInputs));
    for i = 1:length(sAllInputs)
        bst_progress('text', sprintf('Reading input files... [%d/%d]', i, length(sAllInputs)));
        % Convert Brainstorm file to FieldTrip structure
        if (i == 1)
            % First call: convert more information
            [ftAllFiles{i}, ResultsMat, VertConn] = out_fieldtrip_results(sAllInputs(i).FileName, OPT.ScoutSel, OPT.ScoutFunc, OPT.TimeWindow, OPT.isAbsolute);
            % Check for TimeBands and Freqs
            OutTimeBands = [];
            OutFreqs = [];
            if strcmpi(sInputsA(1).FileType, 'results')
                sMat = in_bst_results(sAllInputs(i).FileName, 0, 'TimeBands', 'Freqs');
            elseif strcmpi(sInputsA(1).FileType, 'timefreq')
                sMat = in_bst_timefreq(sAllInputs(i).FileName, 0, 'TimeBands', 'Freqs');
            end
            if ~isempty(sMat.TimeBands)
                OutTimeBands = sMat.TimeBands;
            end
            if ~isempty(sMat.Freqs)
                OutFreqs = sMat.Freqs;
            end
            % Use the information from the first file for all the files
            nComponents = ResultsMat.nComponents;
            GridAtlas   = ResultsMat.GridAtlas;
            RowNames    = ResultsMat.RowNames;
            % Save time vector for output
            if (length(ResultsMat.Time) == 1)
                sfreq = 1000;
            else
                sfreq = 1/(ResultsMat.Time(2) - ResultsMat.Time(1));
            end
            OutTime = ftAllFiles{i}.time;
            if (length(OutTime) == 1)
                OutTime = OutTime + [0, 1/sfreq];
            end
        else
            % Following calls: Just get the source values
            ftAllFiles{i} = out_fieldtrip_results(sAllInputs(i).FileName, OPT.ScoutSel, OPT.ScoutFunc, OPT.TimeWindow, OPT.isAbsolute);
        end
        % Check that something was read
        if isempty(ftAllFiles{i}.pow)
            bst_report('Error', sProcess, sAllInputs(i), 'Nothing read from the file.');
            return;
        end
        % Time average
        if OPT.isAvgTime
            if strcmpi(ftAllFiles{i}.dimord, 'pos_time')
                ftAllFiles{i}.pow  = mean(ftAllFiles{i}.pow, 2);
            elseif strcmpi(ftAllFiles{i}.dimord, 'pos_freq_time')
                ftAllFiles{i}.pow  = mean(ftAllFiles{i}.pow, 3);
            else
                error('todo');
            end
            ftAllFiles{i}.time = ftAllFiles{i}.time(1);
            if (i == 1)
                OutTime = OutTime([1,end]);
                if ~isempty(OutTimeBands)
                    % Update TimeBand
                    OutTimeBands = OutTimeBands(1,:);
                    OutTimeBands{1} = 'TimeBand';
                    OutTimeBands{2} = sprintf('%f, %f', OutTime);
                    OutTimeBands{3} = 'mean';
                end
            end
        end
        % Frequency average ('isAvgFreq' option only exists for 'timefreq' inputs)
        if isfield(OPT, 'isAvgFreq') && OPT.isAvgFreq && strcmpi(ftAllFiles{i}.dimord, 'pos_freq_time') && (size(ftAllFiles{i}.pow,2) > 1)
            ftAllFiles{i}.pow  = mean(ftAllFiles{i}.pow, 2);
            ftAllFiles{i}.freq = ftAllFiles{i}.freq(1);
            if (i == 1)
                if ~iscell(sMat.Freqs)
                    OutFreqs = OutFreqs([1,end]);
                else
                    % Update Freqs (bands)
                    freqBounds = process_tf_bands('GetBounds', OutFreqs);
                    OutFreqs = OutFreqs(1,:);
                    OutFreqs{1} = 'FreqBand';
                    OutFreqs{2} = sprintf('%f, %f', freqBounds(1,1), freqBounds(end,2));
                    OutFreqs{3} = 'mean';
                end
            end
        end
        % Check that all the files have the same dimensions as the first one
        if (i > 1)
            if ~isequal(size(ftAllFiles{i}.pow,1), size(ftAllFiles{1}.pow,1))
                bst_report('Error', sProcess, [], sprintf('All the files must have the same number of sources.\nFile #%d has %d sources, file #%d has %d sources.', 1, size(ftAllFiles{1}.pow,1), i, size(ftAllFiles{i}.pow,1)));
                return;
            elseif ~isequal(size(ftAllFiles{i}.pow,2), size(ftAllFiles{1}.pow,2))
                bst_report('Error', sProcess, [], sprintf('All the files must have the same number of time samples.\nFile #%d has %d samples, file #%d has %d samples.', 1, size(ftAllFiles{1}.pow,2), i, size(ftAllFiles{i}.pow,2)));
                return;
            elseif ~isequal(size(ftAllFiles{i}.pow,3), size(ftAllFiles{1}.pow,3))
                bst_report('Error', sProcess, [], sprintf('All the files must have the same number of frequency bins.\nFile #%d has %d samples, file #%d has %d bins.', 1, size(ftAllFiles{1}.pow,3), i, size(ftAllFiles{i}.pow,3)));
                return;
%             elseif isfield(ftAllFiles{1}, 'freq') && (abs(ftAllFiles{1}.freq(1) - ftAllFiles{i}.freq(1)) > 0)
%                 bst_report('Error', sProcess, [], 'The frequency definitions of the input files do not match.');
%                 return;
%             elseif (abs(ftAllFiles{1}.time(1) - ftAllFiles{i}.time(1)) > 1e-6)
%                 bst_report('Error', sProcess, [], 'The time definitions of the input files do not match.');
%                 return;
            % Only one time point: use the time of the first file
            elseif (length(ftAllFiles{i}.time) == 1)
                ftAllFiles{i}.time = ftAllFiles{1}.time;
            end
        end
    end
            
    % ===== CALL FIELDTRIP =====
    bst_progress('text', 'Calling FieldTrip function: ft_sourcestatistics...');
    % Input options
    statcfg = struct();
    statcfg.method            = 'montecarlo';
    statcfg.numrandomization  = OPT.Randomizations;
    statcfg.statistic         = OPT.StatisticType; 
    statcfg.tail              = OPT.Tail;
    statcfg.correcttail       = 'prob';
    statcfg.parameter         = 'pow';
    
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
    
    % Correction for multiple comparisons
    statcfg.correctm = OPT.Correction;
    switch (OPT.Correction)
        case 'no'
        case {'cluster', 'tfce'}
            % Define parameters for cluster statistics
            statcfg.clusteralpha     = OPT.ClusterAlphaValue;
            statcfg.clustertail      = statcfg.tail;
            statcfg.minnbchan        = OPT.MinNbChan; 
            statcfg.clusterstatistic = OPT.ClusterStatistic;
            % Keep only the selected vertices in the vertex adjacency matrix
            if ~isempty(VertConn) && isempty(OPT.ScoutSel)
                statcfg.connectivity = full(VertConn);
            else
                statcfg.connectivity = zeros(size(ftAllFiles{1}.pos, 1)); 
            end
        case 'bonferroni'
        case 'fdr'
        case 'max'
        case 'holm'
        case 'hochberg'
    end

    % Main function that will compute the statistics
    ftStat = ft_sourcestatistics(statcfg, ftAllFiles{:});
    % Error management
    if ~isfield(ftStat, 'prob') || ~isfield(ftStat, 'stat') || isempty(ftStat.prob) || isempty(ftStat.stat)
        bst_report('Error', sProcess, [], 'Unknown error: The function ft_sourcestatistics did not return anything.');
        return;
    end
    % Apply thresholded mask on the p-values (the prob map is already thresholded for clusters)
    if ~ismember(OPT.Correction, {'no', 'cluster', 'tfce'})
        ftStat.prob(~ftStat.mask) = .999;
    end
    % Replace NaN values with zeros
    ftStat.stat(isnan(ftStat.stat)) = 0;
    
    % Time-frequency: Permute matrices back
    if strcmpi(sInputsA(1).FileType, 'timefreq')
        ftStat.prob = permute(ftStat.prob, [1 3 2]);
        ftStat.stat = permute(ftStat.stat, [1 3 2]);
        if isfield(ftStat, 'posclusterslabelmat') && ~isempty(ftStat.posclusterslabelmat)
            ftStat.posclusterslabelmat = permute(ftStat.posclusterslabelmat, [1 3 2]);
        end
        if isfield(ftStat, 'negclusterslabelmat') && ~isempty(ftStat.negclusterslabelmat)
            ftStat.negclusterslabelmat = permute(ftStat.negclusterslabelmat, [1 3 2]);
        end
        if isfield(ftStat, 'cirange') && ~isempty(ftStat.cirange)
            ftStat.cirange = permute(ftStat.cirange, [1 3 2]);
        end
        if isfield(ftStat, 'mask') && ~isempty(ftStat.mask)
            ftStat.mask = permute(ftStat.mask, [1 3 2]);
        end
        if isfield(ftStat, 'ref') && ~isempty(ftStat.ref)
            ftStat.ref = permute(ftStat.ref, [1 3 2]);
        end
    end
    
    % === OUTPUT STRUCTURE ===
    sOutput = db_template('statmat');
    % Store t- and p-values
    sOutput.pmap = ftStat.prob;
    sOutput.tmap = ftStat.stat;
    % Store other stuff
    sOutput.df            = [];
    sOutput.Correction    = OPT.Correction;
    sOutput.ColormapType  = 'stat2';
    sOutput.DisplayUnits  = 't';
    % Output type
    if ~isempty(OPT.ScoutSel)
        sOutput.Type = 'matrix';
        sOutput.Description = RowNames;
    else
        sOutput.Type = sInputsA(1).FileType;
    end
    % Source model fields
    sOutput.nComponents = nComponents;
    sOutput.GridAtlas   = GridAtlas;
    % Time: If there is only one time point, replicate to have two
    if (length(ftStat.time) == 1)
        sOutput.Time = [OutTime(1), OutTime(end)];
        sOutput.tmap = [sOutput.tmap(:,1,:), sOutput.tmap(:,1,:)];
        sOutput.pmap = [sOutput.pmap(:,1,:), sOutput.pmap(:,1,:)];
    else
        sOutput.Time = ftStat.time;
    end
    % TimeBands
    sOutput.TimeBands = OutTimeBands;
    % FreqBands
    if strcmpi(sInputsA(1).FileType, 'timefreq')
        sOutput.Freqs = OutFreqs;
    end
    % Save clusters
    if isfield(ftStat, 'posclusters')
        sOutput.StatClusters.posclusters         = ftStat.posclusters;
        sOutput.StatClusters.posclusterslabelmat = ftStat.posclusterslabelmat;
        sOutput.StatClusters.posdistribution     = ftStat.posdistribution;
    end
    if isfield(ftStat, 'negclusters')
        sOutput.StatClusters.negclusters         = ftStat.negclusters;
        sOutput.StatClusters.negclusterslabelmat = ftStat.negclusterslabelmat;
        sOutput.StatClusters.negdistribution     = ftStat.negdistribution;
    end
    % Save FieldTrip configuration structure
    sOutput.cfg = statcfg;
    if isfield(sOutput.cfg, 'connectivity')
        sOutput.cfg = rmfield(sOutput.cfg, 'connectivity');
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




