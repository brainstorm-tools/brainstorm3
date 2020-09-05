function varargout = process_ttest_baseline( varargin )
% PROCESS_TTEST_BASELINE: Student''s t-test of a post-stimulus signal vs. a baseline.

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
% Authors: Francois Tadel, 2010-2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Parametric t-test against baseline';
    sProcess.Category    = 'Stat1';
    sProcess.SubGroup    = 'Test';
    sProcess.Index       = 702;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Statistics';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data',  'results',  'timefreq',  'matrix'};
    sProcess.OutputTypes = {'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    
    % Definition of the options
    % === Baseline time window
    sProcess.options.prestim.Comment = 'Pre-simulus:   ';
    sProcess.options.prestim.Type    = 'baseline';
    sProcess.options.prestim.Value   = [];
    % === Baseline time window
    sProcess.options.poststim.Comment = 'Post-simulus: ';
    sProcess.options.poststim.Type    = 'poststim';
    sProcess.options.poststim.Value   = [];
    % === TEST LEGEND
    sProcess.options.label1.Comment   = ['<BR><B>&nbsp;&nbsp;Test formula:</B><BR>' ...
                                         '&nbsp;&nbsp;t = X(post-stim) / std(X(pre-stim))<BR><BR>'];
    sProcess.options.label1.Type       = 'label';
    % === NORM XYZ
    sProcess.options.isnorm.Comment    = 'Compute absolute values (or norm for unconstrained sources)';
    sProcess.options.isnorm.Type       = 'checkbox';
    sProcess.options.isnorm.Value      = 0;
    sProcess.options.isnorm.InputTypes = {'results'};
    % === ABSOLUTE VALUE
    sProcess.options.isabs.Comment    = 'Compute absolute values';
    sProcess.options.isabs.Type       = 'checkbox';
    sProcess.options.isabs.Value      = 0;
    sProcess.options.isabs.InputTypes = {'data', 'timefreq', 'matrix'};
    % === MATCH ROWS WITH NAMES
    sProcess.options.matchrows.Comment    = 'Match signals between files using their names';
    sProcess.options.matchrows.Type       = 'checkbox';
    sProcess.options.matchrows.Value      = 1;
    sProcess.options.matchrows.InputTypes = {'timefreq', 'matrix'};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Get time windows
    if isfield(sProcess.options, 'prestim') && isfield(sProcess.options.prestim, 'Value') && iscell(sProcess.options.prestim.Value) && ~isempty(sProcess.options.prestim.Value) && ~isempty(sProcess.options.prestim.Value{1})
        prestim = sProcess.options.prestim.Value{1};
    else
        prestim = [];
    end
    poststim = sProcess.options.poststim.Value{1};
    units = sProcess.options.poststim.Value{2};
    % Absolute values / Norm
    if isfield(sProcess.options, 'isabs') && isfield(sProcess.options.isabs, 'Value') && sProcess.options.isabs.Value
        strAbs = ' [abs]';
    elseif isfield(sProcess.options, 'isnorm') && isfield(sProcess.options.isnorm, 'Value') && sProcess.options.isnorm.Value
        strAbs = ' [norm]';
    else
        strAbs = '';
    end
    % Time
    if strcmpi(units, 'ms')
        prestim  = round(1000 * prestim);
        poststim = round(1000 * poststim);
        f = '%dms';
    else
        f = '%1.3fs';
    end
    % Comment
    if ~isempty(prestim)
        Comment = sprintf(['t-test' strAbs ': [' f ',' f '] vs. [' f ',' f ']'], poststim(1), poststim(2), prestim(1), prestim(2));
    else
        Comment = sprintf(['t-test' strAbs ': [' f ',' f '] vs. [All file]'], poststim(1), poststim(2));
    end
end


%% ===== RUN =====
function sOutput = Run(sProcess, sInputs) %#ok<DEFNU>   
    % === GET OPTIONS ===
    % Absolute value
    isAbsolute = 0;
    if isfield(sProcess.options, 'isabs') && isfield(sProcess.options.isabs, 'Value')
        isAbsolute = sProcess.options.isabs.Value;
    end
    if isfield(sProcess.options, 'isnorm') && isfield(sProcess.options.isnorm, 'Value')
        isAbsolute = sProcess.options.isnorm.Value;
    end
    % Average function
    if isAbsolute
        AvgFunction = 'norm';
    else
        AvgFunction = 'mean';
    end
    % Match signals between files using their names
    if isfield(sProcess.options, 'matchrows') && isfield(sProcess.options.matchrows, 'Value') && ~isempty(sProcess.options.matchrows.Value)
        isMatchRows = sProcess.options.matchrows.Value;
    else
        isMatchRows = 1;
    end
    
    % === AVERAGE FILES ===
    % Compute mean across all the files
    isVariance = 0;
    isWeighted = 0;
    [Stat, Messages] = bst_avg_files({sInputs.FileName}, [], AvgFunction, isVariance, isWeighted, isMatchRows);
    if ~isempty(Messages)
        bst_report('Error', sProcess, sInputs, Messages);
    end
    % Results?
    isResults = strcmpi(sInputs(1).FileType, 'results');
    % Initialize output structure
    sOutput = db_template('statmat');  
    
    % Get time
    Time = Stat.Time;
    % Bad channels: For recordings, keep only the channels that are good in BOTH A and B sets
    switch lower(sInputs(1).FileType)
        case 'data'
            ChannelFlag = Stat.ChannelFlag;
            iGood = find(ChannelFlag == 1);
            sOutput.ColormapType = 'stat2';
        case 'results'
            iGood = 1:size(Stat.mean, 1);
            ChannelFlag = [];
            sOutput.ColormapType = 'stat1';
        case 'timefreq'
            iGood = 1:size(Stat.mean, 1);
            ChannelFlag = [];
            sOutput.ColormapType = 'stat1';
            % Read some info from the first file
            TimefreqMat = in_bst_timefreq(sInputs(1).FileName, 0, 'TimeBands');
            % Check if the time vector matches the data size, if not it's a file with time bands => error
            if isfield(TimefreqMat, 'TimeBands') && ~isempty(TimefreqMat.TimeBands) 
                bst_report('Error', sProcess, sInputs, ['Cannot process files with time bands.' 10 'Please use files with a full time definition.']);
                sOutput = [];
                return;
            end
        case 'matrix'
            iGood = 1:size(Stat.mean, 1);
            ChannelFlag = [];
    end
    
    % === GET INFORMATION ===
    % Display progress bar
    bst_progress('start', 'Processes', 'Computing t-test...');
    % Get pre-stim indices
    if isfield(sProcess.options, 'prestim') && isfield(sProcess.options.prestim, 'Value') && iscell(sProcess.options.prestim.Value) && ~isempty(sProcess.options.prestim.Value) && ~isempty(sProcess.options.prestim.Value{1})
        PreStimBounds = sProcess.options.prestim.Value{1};
    else
        PreStimBounds = [];
    end
    if ~isempty(PreStimBounds)
        iPreStim = bst_closest(sProcess.options.prestim.Value{1}, Time);
        if (iPreStim(1) == iPreStim(2)) && any(iPreStim(1) == Time)
            bst_report('Error', sProcess, sInputs, 'Invalid pre-stim time window definition.');
            sOutput = [];
            return;
        end
        iPreStim = iPreStim(1):iPreStim(2);
    else
        iPreStim = 1:length(Time);
    end
    % Get post-stim indices
    iPostStim = bst_closest(sProcess.options.poststim.Value{1}, Time);
    if (iPostStim(1) == iPostStim(2)) && any(iPostStim(1) == Time)
        bst_report('Error', sProcess, sInputs, 'Invalid pre-stim time window definition.');
        sOutput = [];
        return;
    end
    iPostStim = iPostStim(1):iPostStim(2);

    % Get data to test
    sizeOutput = size(Stat.mean);
    X = Stat.mean(iGood,:,:);

    % === COMPUTE TEST ===
    % Formula: t = x_post / std(x_pre)
    % Compute variance over baseline (pre-stim interval)
    stdPre = std(X(:,iPreStim,:), 0, 2);
    % Replace null values
    iNull = find(stdPre == 0);
    stdPre(iNull) = 1;
    % Compute t-statistics (formula from wikipedia)
    t_tmp = bst_bsxfun(@rdivide, X(:,iPostStim,:), stdPre);
    % Degrees of freedom for this test
    df = length(iPreStim) - 1;
    % Remove values with null variances
    if ~isempty(iNull)
        t_tmp(iNull,:,:) = 0;
    end
    
    % === CREATE RESULT STRUCTURE ===
    sOutput.tmap = zeros(sizeOutput);
    sOutput.tmap(iGood,iPostStim,:) = t_tmp;
    %sOutput.pmap = betainc( df ./ (df + sOutput.tmap .^ 2), df/2, 0.5);
    sOutput.Time         = Time;
    sOutput.df           = df;
    sOutput.Correction   = 'no';
    sOutput.ChannelFlag  = ChannelFlag;
    sOutput.ColormapType = 'stat2';
    sOutput.DisplayUnits = 't';
    
    % If the number of components may have changed
    if isResults && strcmpi(AvgFunction, 'norm')
        ResultsMat = in_bst(sInputs(1).FileName);
        % Unconstrained or mixed sources: source maps have been flattened by during the averaging
        if (ResultsMat.nComponents ~= 1)
            % Flatten the first file to get the modified variables
            ResultsMat = process_source_flat('Compute', ResultsMat, 'rms');
            sOutput.nComponents = ResultsMat.nComponents;
            sOutput.GridAtlas   = ResultsMat.GridAtlas;
        end
    end
    % Row names
    if isfield(Stat, 'RowNames') && ~isempty(Stat.RowNames)
        if strcmpi(sInputs(1).FileType, 'matrix')
            sOutput.Description = Stat.RowNames;
        else
            sOutput.RowNames = Stat.RowNames;
        end
    end
end




