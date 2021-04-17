function varargout = process_ttest( varargin )
% PROCESS_TTEST: Student''s t-test: Compare means between conditions (across trials or across sujects).

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
% Authors: Francois Tadel, Dimitrios Pantazis, 2008-2015

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Parametric t-test [DEPRECATED]';
    sProcess.Category    = 'Stat2';
    sProcess.SubGroup    = 'Test';
    sProcess.Index       = 120;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Statistics';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data',  'results',  'timefreq',  'matrix'};
    sProcess.OutputTypes = {'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 2;

    % Definition of the options
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
    
    % === T-TEST: title
    sProcess.options.ttest_title.Comment    = '<BR>Test function:';
    sProcess.options.ttest_title.Type       = 'label';
    sProcess.options.ttest_title.InputTypes = {'results'};
    % === T-TEST: type
    sProcess.options.testtype.Comment = {['<B>Equal variance</B>:<BR>t = (m1-m2) / (Sx * sqrt(1/n1 + 1/n2))<BR>' ...
                                          'Sx = sqrt(((n1-1)*v1 + (n2-1)*v2) ./ (n1+n2-2))'], ...
                                         ['<B>Unequal variance</B>:<BR>', ...
                                          't = (m1-m2) / sqrt(v1/n1 + v2/n2)']};
    sProcess.options.testtype.Type    = 'radio';
    sProcess.options.testtype.Value   = 1;
    % === T-TEST: legend
    sProcess.options.ttest_label.Comment    = ['<FONT color="#777777">n1,n2: Number of samples in each group<BR>' ...
                                               'm1,m2: Average across the files for each group<BR>' ...
                                               'v1,v2: Unbiased estimator of the variance across the files</FONT><BR>'];
    sProcess.options.ttest_label.Type       = 'label';
    
    % === Absolue values: legend
    sProcess.options.abs_label.Comment    = '<BR>Function to estimate the average across the files:';
    sProcess.options.abs_label.Type       = 'label';
    sProcess.options.abs_label.InputTypes = {'data', 'results', 'matrix'};
    % === Absolue values: type
    sProcess.options.avg_func.Comment = {'Arithmetic average: <FONT color="#777777">mean(x)&nbsp;&nbsp;&nbsp;&nbsp;</FONT>', ...
                                         'Absolute value of average: <FONT color="#777777">abs(mean(x))&nbsp;&nbsp;&nbsp;&nbsp;[WRONG]</FONT>', ...
                                         'Average of absolute values:  <FONT color="#777777">mean(abs(x))</FONT>'};
    sProcess.options.avg_func.Type    = 'radio';
    sProcess.options.avg_func.Value   = 2;
    sProcess.options.avg_func.InputTypes = {'data', 'results', 'matrix'};
    % === MATCH ROWS WITH NAMES
    sProcess.options.matchrows.Comment    = 'Match signals between files using their names';
    sProcess.options.matchrows.Type       = 'checkbox';
    sProcess.options.matchrows.Value      = 1;
    sProcess.options.matchrows.InputTypes = {'timefreq', 'matrix'};
    % === WEIGHTED AVERAGE
    sProcess.options.label_wavg.Comment    = ['<FONT color="#777777">Note: When processing averages, "mean" refers to a weighted average:<BR>' ...
                                              'mean(F) = sum(nAvg(i) * F(i)) / sum(nAvg(i))</FONT>'];
    sProcess.options.label_wavg.Type       = 'label';
    % === UNCONSTRAINED SOURCES
    sProcess.options.label_norm.Comment    = ['<FONT color="#777777">Note: For unconstrained sources, "absolute value" refers to the norm<BR>' ...
                                              'of the three orientations: abs(F) = sqrt(Fx^2 + Fy^2 + Fz^2).</FONT>'];
    sProcess.options.label_norm.Type       = 'label';
    sProcess.options.label_norm.InputTypes = {'results'};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % If sources: averaging option
    if isfield(sProcess.options, 'avg_func')
        switch(sProcess.options.avg_func.Value)
            case 1,  strAvgType = '';
            case 2,  strAvgType = ', abs(avg)';
            case 3,  strAvgType = ', avg(abs)';
        end
    else
        strAvgType = '';
    end
    % Test type
    switch (sProcess.options.testtype.Value)
        case 1,  Comment = ['t-test [equal var' strAvgType ']'];
        case 2,  Comment = ['t-test [unequal var' strAvgType ']'];
    end
end


%% ===== RUN =====
function sOutput = Run(sProcess, sInputsA, sInputsB) %#ok<DEFNU>
    % ===== PARSE INPUTS =====
    % Make sure that file type is indentical for both sets
    if ~isempty(sInputsA) && ~isempty(sInputsB) && ~strcmpi(sInputsA(1).FileType, sInputsB(1).FileType)
        bst_report('Error', sProcess, sInputsA, 'Cannot process inputs from different types.');
        sOutput = [];
        return;
    end
    % Check the number of files in input
    if (length(sInputsA) < 2) || (length(sInputsB) < 2)
        bst_report('Error', sProcess, sInputsA, 'Not enough files in input.');
        sOutput = [];
        return;
    end
    % Scouts
    if isfield(sProcess.options, 'scoutsel') && isfield(sProcess.options.scoutsel, 'Value') && isfield(sProcess.options, 'scoutfunc') && isfield(sProcess.options.scoutfunc, 'Value')
        ScoutSel = sProcess.options.scoutsel.Value;
        switch (sProcess.options.scoutfunc.Value)
            case 1, ScoutFunc = 'mean';
            case 2, ScoutFunc = 'pca';
            case 3, ScoutFunc = 'all';
        end
    else
        ScoutSel = [];
        ScoutFunc = [];
    end
    % Match signals between files using their names
    if isfield(sProcess.options, 'matchrows') && isfield(sProcess.options.matchrows, 'Value') && ~isempty(sProcess.options.matchrows.Value)
        isMatchRows = sProcess.options.matchrows.Value;
    else
        isMatchRows = 1;
    end
    % Get variance hypothesis
    isEqualVar = (sProcess.options.testtype.Value == 1);
    % Get average type
    if isfield(sProcess.options, 'avg_func')
        switch (sProcess.options.avg_func.Value)
            case 1,  Function = 'mean'; isAbsTest = 0;
            case 2,  Function = 'mean'; isAbsTest = 1;
            case 3,  Function = 'norm'; isAbsTest = 0;
        end
    else
        Function = 'mean';
        isAbsTest = 0;
    end
    % Dimensions
    n1 = length(sInputsA);
    n2 = length(sInputsB);
    % Results?
    isResults = strcmpi(sInputsA(1).FileType, 'results');
    isScouts  = ~isempty(ScoutSel);
    % Initialize output structure
    sOutput = db_template('statmat');
    
    % ===== COMPUTE AVERAGE AND VARIANCE =====
    % Scouts: Need to load them here
    if isScouts
        InputSetA = bst_process('LoadScouts', {sInputsA.FileName}, ScoutSel, ScoutFunc, []);
        InputSetB = bst_process('LoadScouts', {sInputsB.FileName}, ScoutSel, ScoutFunc, []);
        sOutput.Type = 'matrix';
    % Other types of data: can be handled directly by bst_avg_files
    else
        InputSetA = {sInputsA.FileName};
        InputSetB = {sInputsB.FileName};
    end
    % Compute mean and var for both files sets
    [StatA, MessagesA] = bst_avg_files({sInputsA.FileName}, [], Function, 1, 0, isMatchRows);
    [StatB, MessagesB] = bst_avg_files({sInputsB.FileName}, [], Function, 1, 0, isMatchRows);
    % Add messages to report
    if ~isempty(MessagesA)
        bst_report('Error', sProcess, sInputsA, MessagesA);
        sOutput = [];
        return;
    end
    if ~isempty(MessagesB)
        bst_report('Error', sProcess, sInputsB, MessagesB);
        sOutput = [];
        return;
    end
    if ~isequal(size(StatA.mean), size(StatB.mean))
        bst_report('Error', sProcess, sInputsB, 'Files A and B do not have the same number of signals or time samples.');
        sOutput = [];
        return;
    end

    % === ABSOLUTE VALUES ===
    % Absolute values before difference
    if isAbsTest
        % Results: read the first file in the list
        if isResults && ~isScouts
            [sMat, matName] = in_bst(sInputsA(1).FileName);
            % Unconstrained sources: Convert to flat map (norm of the three orientations)
            if isfield(sMat, 'nComponents') && (sMat.nComponents ~= 1)
                % Average A
                sMatTmp = sMat;
                sMat.(matName) = StatA.mean;
                sMat = process_source_flat('Compute', sMat, 'rms');
                StatA.mean = sMat.(matName);
                % Average B
                sMat = sMatTmp;
                sMat.(matName) = StatB.mean;
                sMat = process_source_flat('Compute', sMat, 'rms');
                StatB.mean = sMat.(matName);
                % Variance A
                sMat = sMatTmp;
                sMat.(matName) = sqrt(StatA.var);
                sMat = process_source_flat('Compute', sMat, 'rms');
                StatA.var = sMat.(matName) .^ 2;
                % Variance B
                sMat = sMatTmp;
                sMat.(matName) = sqrt(StatB.var);
                sMat = process_source_flat('Compute', sMat, 'rms');
                StatB.var = sMat.(matName) .^ 2;
                % Report modified variables
                sOutput.nComponents = sMat.nComponents;
                sOutput.GridAtlas   = sMat.GridAtlas;
            end
        end
        % Enforce absolute values
        StatA.mean = abs(StatA.mean);
        StatB.mean = abs(StatB.mean);
    end
    % Display progress bar
    bst_progress('start', 'Processes', 'Computing t-test...');

    % Bad channels: For recordings, keep only the channels that are good in BOTH A and B sets
    switch lower(sInputsA(1).FileType)
        case 'data'
            ChannelFlag = StatA.ChannelFlag;
            ChannelFlag(StatB.ChannelFlag == -1) = -1;
            isGood = (ChannelFlag == 1);
        case {'results', 'timefreq', 'matrix'}
            ChannelFlag = [];
            isGood = true(size(StatA.mean, 1), 1);            
    end
    sizeOutput = size(StatA.mean);
    
    % === INDEPENDENT T-TEST ===
    % Get results
    a1 = StatA.mean(isGood,:,:);
    a2 = StatB.mean(isGood,:,:);
    v1 = StatA.var(isGood,:,:);
    v2 = StatB.var(isGood,:,:);
    % Remove null variances
    iNull = find((v1 == 0) | (v2 == 0));
    v1(iNull) = eps;
    v2(iNull) = eps;

    % Compute t-test: Formulas come from Wikipedia page: Student's t-test
    if isEqualVar
        df_tmp = n1 + n2 - 2 ;
        pvar = ((n1 - 1) * v1 + (n2 - 1) * v2) / df_tmp ;
        t_tmp = (a1 - a2) ./ sqrt( pvar * (1/n1 + 1/n2)) ;
    else
        df_tmp = (v1 / n1 + v2 / n2).^2 ./ ...
                 ( (v1 / n1).^2 / (n1 - 1) + (v2 / n2).^2 / (n2 - 1) ) ;
        t_tmp = (a1 - a2) ./ sqrt( v1 / n1 + v2 / n2 ) ;
    end
    clear a1 a2 v1 v2

    % Remove values with null variances
    if ~isempty(iNull)
        t_tmp(iNull) = 0;
    end
    
    % === OUTPUT STRUCTURE ===
    % Initialize p and t matrices
    if (nnz(isGood) == length(ChannelFlag))
        sOutput.tmap = t_tmp;
        sOutput.df = df_tmp;
    else
        sOutput.tmap = zeros(sizeOutput);
        sOutput.tmap(isGood,:,:) = t_tmp;
        if ~isEqualVar
            sOutput.df = zeros(sizeOutput);
            sOutput.df(isGood,:,:) = df_tmp;
        else
            sOutput.df = df_tmp;
        end
    end
    %sOutput.pmap = betainc( df ./ (df + sOutput.tmap .^ 2), df/2, 0.5);
    sOutput.Correction   = 'no';
    sOutput.ChannelFlag  = ChannelFlag;
    sOutput.Time         = StatA.Time;
    sOutput.ColormapType = 'stat2';
    sOutput.DisplayUnits = 't';
    
    % If the number of components may have changed outside of this function
    if isResults && strcmpi(Function, 'norm') && ~isScouts
        ResultsMat = in_bst(sInputsA(1).FileName);
        % Unconstrained or mixed sources: source maps have been flattened by bst_avg_files
        if (ResultsMat.nComponents ~= 1)
            % Flatten the first file to get the modified variables
            ResultsMat = process_source_flat('Compute', ResultsMat, 'rms');
            sOutput.nComponents = ResultsMat.nComponents;
            sOutput.GridAtlas   = ResultsMat.GridAtlas;
        end
    end
    % Row names
    if isfield(StatA, 'RowNames') && ~isempty(StatA.RowNames)
        if strcmpi(sInputsA(1).FileType, 'matrix') || isScouts
            sOutput.Description = StatA.RowNames;
        else
            sOutput.RowNames = StatA.RowNames;
        end
    end
end


