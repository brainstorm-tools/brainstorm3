function varargout = process_test_parametric2( varargin )
% PROCESS_TEST_PARAMETRIC2: Parametric two-sample tests (independent).
% 
% USAGE:  OutputFiles = process_test_parametric2('Run', sProcess, sInput)
%                   p = process_test_parametric2('ComputePvalues', t, df, TestType='t', TestTail='two')

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
% Authors: Francois Tadel, Dimitrios Pantazis, 2008-2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Parametric test: Independent';
    sProcess.Category    = 'Stat2';
    sProcess.SubGroup    = 'Test';
    sProcess.Index       = 101;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Statistics';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data',  'results',  'timefreq',  'matrix'};
    sProcess.OutputTypes = {'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 2;

    % === GENERIC EXTRACT OPTIONS
    % Label
    sProcess.options.extract_title.Comment    = '<B><U>Select data to test</U></B>:';
    sProcess.options.extract_title.Type       = 'label';
    % Options
    sProcess = process_extract_values('DefineExtractOptions', sProcess);
    % DISABLE ABSOLUTE VALUE
    sProcess.options.isabs.Value = 0;
    sProcess.options.isnorm.Value = 0;
    sProcess.options.isabs.Hidden = 1;
    sProcess.options.isnorm.Hidden = 1;
    
    % === EXCLUDE ZERO VALUES
    sProcess.options.iszerobad.Comment    = 'Exclude the zero values from the computation';
    sProcess.options.iszerobad.Type       = 'checkbox';
    sProcess.options.iszerobad.Value      = 1;
    sProcess.options.iszerobad.InputTypes = {'timefreq', 'matrix'};
    % === OUTPUT COMMENT
    sProcess.options.Comment.Comment = 'Comment (empty=default): ';
    sProcess.options.Comment.Type    = 'text';
    sProcess.options.Comment.Value   = '';
    
    % === TEST: title
    sProcess.options.test_title.Comment    = '<BR><B><U>Test statistic</U></B>:';
    sProcess.options.test_title.Type       = 'label';
    % === TEST: type
    sProcess.options.test_type.Comment = {['<B>Student''s t-test &nbsp;&nbsp;(equal variance)</B> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <FONT COLOR="#777777"><I>A,B~N(m,v)</I></FONT><BR>' ...
                                           't = (mean(A)-mean(B)) / (Sx * sqrt(1/nA + 1/nB))<BR>' ...
                                           'Sx = sqrt(((nA-1)*var(A) + (nB-1)*var(B)) / (nA+nB-2)) <BR>' ...
                                           '<FONT COLOR="#777777">df = nA + nB - 2</FONT>'], ...
                                          ['<B>Student''s t-test &nbsp;&nbsp;(unequal variance)</B> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <FONT COLOR="#777777"><I>A,B~N(m,v)</I></FONT><BR>', ...
                                           't = (mean(A)-mean(B)) / sqrt(var(A)/nA + var(B)/nB)<BR>' ...
                                           '<FONT COLOR="#777777">df=(vA/nA+vB/nB)<SUP>2</SUP> / ((vA/nA)<SUP>2</SUP>/(nA-1)+(vB/nB)<SUP>2</SUP>/(nB-1))</FONT>'], ...
                                          ['<B>Power F-test</B> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <FONT COLOR="#777777"><I>A~N(0,vA), B~N(0,vB)</I></FONT><BR>', ...
                                           'F = (sum(A^2)/nA) / (sum(B^2)/nB) &nbsp;&nbsp;&nbsp;&nbsp; <FONT COLOR="#777777"><I>~F(nA,nB)</I></FONT>'], ...
                                          ['<B>Power F-test (unconstrained sources)</B><BR>', ...
                                           'F = (sum(Ax<SUP>2</SUP>+Ay<SUP>2</SUP>+Az<SUP>2</SUP>)/nA) / (sum(Bx<SUP>2</SUP>+By<SUP>2</SUP>+Bz<SUP>2</SUP>)/nB)<BR>', ... 
                                           '<FONT COLOR="#777777"><I>Ax,Ay,Az~N(0,vA), Bx,By,Bz~N(0,vB), F~F(3*nA,3*nB)</I></FONT>']; ...
                                          'ttest_equal', 'ttest_unequal', 'power', 'power_unconstr'};
    sProcess.options.test_type.Type    = 'radio_label';
    sProcess.options.test_type.Value   = 'ttest_equal';
    % === TAIL FOR THE TEST STATISTIC
    sProcess.options.tail.Comment  = {'One-tailed (-)', 'Two-tailed', 'One-tailed (+)', ''; ...
                                      'one-', 'two', 'one+', ''};
    sProcess.options.tail.Type     = 'radio_linelabel';
    sProcess.options.tail.Value    = 'two';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % === DATA SELECTION COMMENT ===
    strData = process_extract_time('GetTimeString', sProcess);
    if isfield(sProcess.options, 'freqrange') && isfield(sProcess.options.freqrange, 'Value') && iscell(sProcess.options.freqrange.Value) && (length(sProcess.options.freqrange.Value) == 3) && (length(sProcess.options.freqrange.Value{1}) == 2)
        FreqRange = sProcess.options.freqrange.Value{1};
        if (FreqRange(1) == FreqRange(2))
            strData = [strData, ' ' num2str(FreqRange(1)) 'Hz'];
        else
            strData = [strData, ' ' num2str(FreqRange(1)) '-' num2str(FreqRange(2)) 'Hz'];
        end
    end
    if isfield(sProcess.options, 'sensortypes') && isfield(sProcess.options.sensortypes, 'Value') && ~isempty(sProcess.options.sensortypes.Value)
        strData = [strData, ' ', sProcess.options.sensortypes.Value];
    end
    if isfield(sProcess.options, 'rows') && isfield(sProcess.options.rows, 'Value') && ~isempty(sProcess.options.rows.Value)
        strData = [strData, ' ', sProcess.options.rows.Value];
    end
    if ~isempty(strData)
        strData = [' [' strData ']'];
    end

    % === ABSOLUTE VALUE ===
    % Get options
    if isfield(sProcess.options, 'isabs') && isfield(sProcess.options.isabs, 'Value') && sProcess.options.isabs.Value
        isAbsolute = 1;
        strAbs = ' abs';
    elseif isfield(sProcess.options, 'isnorm') && isfield(sProcess.options.isnorm, 'Value') && sProcess.options.isnorm.Value
        isAbsolute = 1;
        strAbs = ' norm';

    else
        isAbsolute = 0;
        strAbs = '';
    end
    
    % === TEST COMMENT ===
    % Get test info
    if isfield(sProcess.options, 'test_type') && isfield(sProcess.options.test_type, 'Value') && ~isempty(sProcess.options.test_type.Value)
        TestType = sProcess.options.test_type.Value;
    else
        TestType = 'ttest_unequal';
    end
    if isfield(sProcess.options, 'tail') && isfield(sProcess.options.tail, 'Value') && ~isempty(sProcess.options.tail.Value)
        TestTail = sProcess.options.tail.Value;
    else
        TestTail = [];
    end
    % Documenting test to perform
    switch (TestType)
        case {'ttest_equal', 'ttest_unequal', 'ttest_paired', 'wilcoxon_paired'}   % , 'wilcoxon'
            strHypo = '          H0:(A=B)';
            switch(TestTail)
                case 'one-',   strHypo = [strHypo, ', H1:(A<B)'];
                case 'two',    strHypo = [strHypo, ', H1:(A<>B)'];
                case 'one+',   strHypo = [strHypo, ', H1:(A>B)'];
            end
        case 'signtest'
            strHypo = '         H0:(A=B), H1:(A<>B)';
        case 'ttest_onesample'
            strHypo = '          H0:(X=0)';
            switch(TestTail)
                case 'one-',   strHypo = [strHypo, ', H1:(X<0)'];
                case 'two',    strHypo = [strHypo, ', H1:(X<>0)'];
                case 'one+',   strHypo = [strHypo, ', H1:(X>0)'];
            end
        case 'ttest_baseline'
            strHypo = '          H0:(X=Baseline)';
            switch(TestTail)
                case 'one-',   strHypo = [strHypo, ', H1:(X<Baseline)'];
                case 'two',    strHypo = [strHypo, ', H1:(X<>Baseline)'];
                case 'one+',   strHypo = [strHypo, ', H1:(X>Baseline)'];
            end
        case {'power_baseline', 'power_baseline_unconstr'}
            strHypo = '          H0:(|X|=|Baseline|)';
            switch(TestTail)
                case 'one-',   strHypo = [strHypo, ', H1:(|X|<|Baseline|)'];
                case 'two',    strHypo = [strHypo, ', H1:(|X|<>|Baseline|)'];
                case 'one+',   strHypo = [strHypo, ', H1:(|X|>|Baseline|)'];
            end
        case 'chi2_onesample'
            strHypo = '          H0:(|Zi| = 0)';
        case 'chi2_onesample_unconstr'
            strHypo = '          H0:(|Zi| = 0)';
        case {'power', 'power_unconstr'}
            strHypo = '          H0:(vA=vB)';
            switch(TestTail)
                case 'one-',   strHypo = [strHypo, ', H1:(vA<vB)'];
                case 'two',    strHypo = [strHypo, ', H1:(vA<>vB)'];
                case 'one+',   strHypo = [strHypo, ', H1:(vA>vB)'];
            end
        case {'absmean', 'absmean_param'}
            strHypo = '          H0:(|mean(A)|=|mean(B)|)';
            switch(TestTail)
                case 'one-',   strHypo = [strHypo, ', H1:(|mean(A)|<|mean(B)|)'];
                case 'two',    strHypo = [strHypo, ', H1:(|mean(A)|<>|mean(B)|)'];
                case 'one+',   strHypo = [strHypo, ', H1:(|mean(A)|>|mean(B)|)'];
            end
    end
    
    % No comment when forcing a one-sided test 
    if ismember(TestType, {'ttest_onesample'}) && isAbsolute
        strTail = '';
    elseif strcmpi(TestType, 'chi2_onesample') || strcmpi(TestType, 'chi2_onesample_unconstr')
        strTail = '';
        strAbs = '';
    elseif strcmpi(TestType, 'signtest')
        strTail = '';
    % Comment for one-tailed tests
    elseif ismember(TestTail, {'one-','one+'})
        strTail = [' ' TestTail];
    else
        strTail = '';
    end

    % === ASSEMBLING ===
    switch (TestType)
        case 'ttest_equal',      Comment = ['t-test equal'     strTail strAbs strData strHypo];
        case 'ttest_unequal',    Comment = ['t-test unequal'   strTail strAbs strData strHypo];
        case 'ttest_paired',     Comment = ['t-test paired'    strTail strAbs strData strHypo];
        case 'ttest_onesample',  Comment = ['t-test zero'      strTail strAbs strData strHypo];
        case 'ttest_baseline',   Comment = ['t-test baseline'  strTail strAbs strData strHypo];
        case 'power_baseline',   Comment = ['power test baseline'  strTail strData strHypo];
        case 'power_baseline_unconstr',   Comment = ['power test baseline unconstr' strTail strData strHypo];
        case 'signtest',         Comment = ['signtest'         strAbs strData strHypo];
        case 'wilcoxon_paired',  Comment = ['wilcoxon paired ' strTail strAbs strData strHypo];
        % case 'wilcoxon',         Comment = ['wilcoxon'       strTail strAbs strData strHypo];
        case 'power',            Comment = ['power test'       strTail strData strHypo];
        case 'power_unconstr',   Comment = ['power test unconstr' strTail strData strHypo];
        case 'chi2_onesample',   Comment = ['Chi2-test'        strTail strData strHypo];
        case 'chi2_onesample_unconstr',  Comment = ['Chi2-test unconstr' strTail strData strHypo];
        case 'absmean',          Comment = ['absmean test'     strTail strData strHypo];
        case 'absmean_param',    Comment = ['absmean test'     strTail strData strHypo];
    end
end


%% ===== RUN =====
function sOutput = Run(sProcess, sInputsA, sInputsB) %#ok<DEFNU>
    % Initialize returned variables
    sOutput = [];
    
    % ===== GET OPTIONS =====
    % Get generic extract options
    OPTIONS = process_extract_values('GetExtractOptions', sProcess, sInputsA(1));
    % Exclude zero values
    if isfield(sProcess.options, 'iszerobad') && isfield(sProcess.options.iszerobad, 'Value') && ~isempty(sProcess.options.iszerobad.Value)
        OPTIONS.isZeroBad = sProcess.options.iszerobad.Value;
    else
        OPTIONS.isZeroBad = 1;
    end
    % Get test type
    OPTIONS.TestType = sProcess.options.test_type.Value;
    OPTIONS.TestTail = sProcess.options.tail.Value;
    % Invalid test/tail combinations
    if ismember(OPTIONS.TestType, {'ttest_onesample'}) && OPTIONS.isAbsolute && ismember(OPTIONS.TestTail, {'two', 'one-'})
        bst_report('Warning', sProcess, [], 'Testing |X|>0: Using a positive one-tailed test (one+) instead.');
        OPTIONS.TestTail = 'one+';
    elseif ismember(OPTIONS.TestType, {'chi2_onesample', 'chi2_onesample_unconstr'}) && ismember(OPTIONS.TestTail, {'two', 'one-'})
        bst_report('Warning', sProcess, [], 'Testing |X|>0: Using a positive one-tailed test (one+) instead.');
        OPTIONS.TestTail = 'one+';
    end
    % Time-frequency: Warning if processing power
    isTfPower = false;
    if strcmpi(sInputsA(1).FileType, 'timefreq')
        TfMat = in_bst_timefreq(sInputsA(1).FileName, 0, 'Measure');
        if isequal(TfMat.Measure, 'power')
            isTfPower = true;
        end
    end    
    % Get average function
    switch (OPTIONS.TestType)
        case {'ttest_equal', 'ttest_unequal', 'ttest_onesample', 'ttest_paired', 'ttest_baseline', 'absmean', 'absmean_param'}
            if isTfPower
                bst_report('Warning', sProcess, [], ['You are testing power values, while a more standard analysis is to test the magnitude (ie. sqrt(power)).' 10 ...
                    'Option #1: Recompute the time-frequency maps using the option "Measure: Magnitude".' 10 ...
                    'Option #2: Run the process "Extract > Measure from complex values", with option "Magntiude".']);
                isTfPower = false;
            end
            if OPTIONS.isAbsolute
                AvgFunction = 'norm';
                isAvgVariance = 1;
            else
                AvgFunction = 'mean';
                isAvgVariance = 1;
            end
        case {'power', 'power_baseline', 'power_baseline_unconstr', 'power_unconstr', 'chi2_onesample', 'chi2_onesample_unconstr'}
            AvgFunction = 'rms';
            isAvgVariance = 0;
    end
    isAvgWeighted = 0;
    % Baseline: Only for test against baseline
    if isfield(sProcess.options, 'baseline') && isfield(sProcess.options.baseline, 'Value') && iscell(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value{1})
        Baseline = sProcess.options.baseline.Value{1};
    else
        Baseline = [];
    end
    % Unconstrained chi2 test: force the computation of norm
    if ismember(OPTIONS.TestType, {'chi2_onesample_unconstr', 'power_baseline_unconstr'})
        OPTIONS.isAbsolute = 1;
    end
            
    % ===== CHECK INPUT FILES =====
    % Make sure that file type is indentical for both sets
    if ~isempty(sInputsA) && ~isempty(sInputsB) && ~strcmpi(sInputsA(1).FileType, sInputsB(1).FileType)
        bst_report('Error', sProcess, [], 'Cannot process inputs from different types.');
        return;
    end
    % Check the number of files in input
    if (length(sInputsA) < 2) && ~strcmpi(OPTIONS.TestType, 'ttest_baseline')
        bst_report('Error', sProcess, [], 'Not enough files in input.');
        return;
    end
    % Load time vector from the first file: if same as input, discard input
    TimeVector = in_bst(sInputsA(1).FileName, 'Time');
    if ~isempty(OPTIONS.TimeWindow) && (abs(TimeVector(1) - OPTIONS.TimeWindow(1)) < 1e-4) && (abs(TimeVector(end) - OPTIONS.TimeWindow(2)) < 1e-4)
        OPTIONS.TimeWindow = [];
    end
    % Load freq range from the first file: if same as input, discard input
    if ~isempty(OPTIONS.FreqRange)
        % Load Freqs field from the input file
        TfMat = in_bst_timefreq(sInputsA(1).FileName, 0, 'Freqs');
        if iscell(TfMat.Freqs)
            BandBounds = process_tf_bands('GetBounds', TfMat.Freqs);
            FreqList = unique(BandBounds(:));
        else
            FreqList = TfMat.Freqs;
        end
        if (abs(OPTIONS.FreqRange(1) - FreqList(1)) < 1e-4) && (abs(OPTIONS.FreqRange(2) - FreqList(end)) < 1e-4)
            OPTIONS.FreqRange = [];
        end
    end
    
    % ===== INPUT DATA =====
    % If there is nothing special done with the files: files can be handled directly by bst_avg_files
    if isempty(OPTIONS.TimeWindow) && isempty(OPTIONS.ScoutSel) && isempty(OPTIONS.SensorTypes) && isempty(OPTIONS.Rows) && isempty(OPTIONS.FreqRange) && ~OPTIONS.isAvgTime && ~OPTIONS.isAvgRow && ~OPTIONS.isAvgFreq && ~isTfPower
        InputSetA = {sInputsA.FileName};
        if ~isempty(sInputsB)
            InputSetB = {sInputsB.FileName};
        else
            InputSetB = [];
        end
        OutputType = sInputsA(1).FileType;
    % Else: Call process "Extract values" first
    else
        % Do not concatenate the output
        OPTIONS.Dim = 0;
        % Call extraction process: FilesA
        [InputSetA, OutputType] = process_extract_values('Extract', sProcess, sInputsA, OPTIONS);
        if isempty(InputSetA)
            return;
        end
        % Read FilesB
        if ~isempty(sInputsB)
            InputSetB = process_extract_values('Extract', sProcess, sInputsB, OPTIONS);
            if isempty(InputSetB)
                return;
            end
        else
            InputSetB = [];
        end
        % Adjust time-frequency already in 'power', for power stats.
        if isTfPower
            bst_report('Info', sProcess, [], 'Data is already power values, adapting power test (not squaring again).');
            for iIn = 1:numel(InputSetA)
                [InputSetA{iIn}.TF, isError] = process_tf_measure('Compute', InputSetA{iIn}.TF, InputSetA{iIn}.Measure, 'magnitude', true);
                if isError
                    bst_report('Error', sProcess, sInputsA(1), ['Error converting time-frequency measure ' InputSetA{iIn}.Measure 'to magnitude.']);
                end
            end
            for iIn = 1:numel(InputSetB)
                [InputSetB{iIn}.TF, isError] = process_tf_measure('Compute', InputSetB{iIn}.TF, InputSetB{iIn}.Measure, 'magnitude', true);
                if isError
                    bst_report('Error', sProcess, sInputsA(1), ['Error converting time-frequency measure ' InputSetB{iIn}.Measure 'to magnitude.']);
                end
            end
        end
    end

    % === COMPUTE TEST ===
    % Branch between dependent(=paired) and independent tests
    switch (OPTIONS.TestType)
        
        % ===== INDEPENDENT TESTS =====
        case {'ttest_equal', 'ttest_unequal', 'absmean', 'absmean_param', 'power', 'power_unconstr'}
            % Compute mean and var for both files sets
            [StatA, MessagesA] = bst_avg_files(InputSetA, [], AvgFunction, isAvgVariance, isAvgWeighted, OPTIONS.isMatchRows, OPTIONS.isZeroBad);
            [StatB, MessagesB] = bst_avg_files(InputSetB, [], AvgFunction, isAvgVariance, isAvgWeighted, OPTIONS.isMatchRows, OPTIONS.isZeroBad);
            % Add messages to report
            if ~isempty(MessagesA)
                if isempty(StatA)
                    bst_report('Error', sProcess, sInputsA, MessagesA);
                    return;
                else
                    bst_report('Warning', sProcess, sInputsA, MessagesA);
                end
            end
            if ~isempty(MessagesB)
                if isempty(StatB)
                    bst_report('Error', sProcess, sInputsB, MessagesB);
                    return;
                else
                    bst_report('Warning', sProcess, sInputsB, MessagesB);
                end
            end
            if ~isequal(size(StatA.mean), size(StatB.mean))
                bst_report('Error', sProcess, [], 'Files A and B do not have the same number of signals or time samples.');
                return;
            end
            % Detect if the source model is unconstrained
            isUnconstrained = panel_scout('isUnconstrained', StatA);
            % Do not allow unconstrained sources without a norm
            if isUnconstrained && ~OPTIONS.isAbsolute
                bst_report('Error', sProcess, [], ['Cannot run this test on unconstrained sources:' 10 'you must compute the norm of the three orientations first.']);
                return;
            end
            % Bad channels: For recordings, keep only the channels that are good in BOTH A and B sets
            if strcmpi(sInputsA(1).FileType, 'data') && ~isempty(StatA.ChannelFlag) && ~isempty(StatB.ChannelFlag)
                ChannelFlag = StatA.ChannelFlag;
                ChannelFlag(StatB.ChannelFlag == -1) = -1;
                isGood = (ChannelFlag == 1);
            else  % case {'results', 'timefreq', 'matrix'}
                ChannelFlag = [];
                isGood = true(size(StatA.mean, 1), 1);
                isGood((StatA.nGoodSamples < 2) | (StatB.nGoodSamples < 2)) = 0;
            end

            % === COMPUTE TEST ===
            % Display progress bar
            bst_progress('start', 'Processes', 'Computing test...');
            % Get average results
            mA = StatA.mean(isGood,:,:);
            mB = StatB.mean(isGood,:,:);
            nA = repmat(StatA.nGoodSamples(isGood,:,:), [1, size(mA,2), size(mA,3)]);
            nB = repmat(StatB.nGoodSamples(isGood,:,:), [1, size(mB,2), size(mB,3)]);
            % Get variance (if needed)
            if isAvgVariance
                vA = StatA.var(isGood,:,:);
                vB = StatB.var(isGood,:,:);
                % Remove null variances
                iNull = find((vA == 0) | (vB == 0));
                vA(iNull) = eps;
                vB(iNull) = eps;
            else
                iNull = [];
            end
            
            % Compute test statistic
            switch (OPTIONS.TestType)
                % === T-TEST: EQUAL VARIANCE ===
                case 'ttest_equal'
                    df   = nA + nB - 2 ;
                    pvar = ((nA-1).*vA + (nB-1).*vB) ./ df;
                    tmap = (mA-mB) ./ sqrt(pvar .* (1./nA + 1./nB));
                    % Calculate p-values from t-values
                    pmap = ComputePvalues(tmap, df, 't', OPTIONS.TestTail);
                    % Units: t
                    DisplayUnits = 't';

                % === T-TEST: UNEQUAL VARIANCE ===
                case 'ttest_unequal'
                    df = (vA./nA + vB./nB).^2 ./ ...
                         ((vA./nA).^2./(nA-1) + (vB./nB).^2./(nB-1));
                    tmap = (mA-mB) ./ sqrt(vA./nA + vB./nB);
                    % Calculate p-values from t-values
                    pmap = ComputePvalues(tmap, df, 't', OPTIONS.TestTail);
                    % Units: t
                    DisplayUnits = 't';
                    
                % ===== POWER TEST (A/B) =====
                case {'power', 'power_unconstr'}
                    % If you have xi, n normal random variables with zero mean and unit variance N(0,1), then:
                    % X1 = sum_i(xi^2) is chi-square random variable with n degrees of freedom
                    % https://en.wikipedia.org/wiki/Chi-squared_distribution
                    %
                    % If X1 and X2 are chi-square random variables with nA and nB degrees of freedom, then
                    % F = (X1/nA) / (X2/nB) is F-distributed with nA numerator degrees of freedom and nB denominator degrees of freedom.
                    % https://en.wikipedia.org/wiki/F-distribution
                    %
                    % Use case here: If A~N(0,vA) and B~N(0,vB)
                    % Then F = (sum(A^2)/nA) / (sum(B^2)/nB)  ~ F(nA,nB)
                    %
                    % Can be used for two things:
                    % 1) Testing for variance difference:   H0:(A~N(0,vA), B~N(0,vB), vA=vB)
                    %    => Samples must be zero-mean (mA=0, mB=0) so probably normalized before testing
                    % 2) Testing for power difference:      H0:(A~N(0,1) and B~(0,1))
                    %    => Samples must be normalized before testing
                    
                    % The output of bst_avg_files is the RMS of A and B:  mA = sqrt(sum(A^2)/nA)
                    % F statistic = (sum(A^2)/nA) / (sum(B^2)/nB)
                    %             = (mA^2) / (mB^2)
                    tmap = mA.^2 ./ mB.^2;
                    % Degrees of freedom
                    if strcmpi(OPTIONS.TestType, 'power_unconstr')
                        df = {3*nA,3*nB};
                    else
                        df = {nA,nB};
                    end
                    % Calculate p-values from t-values
                    pmap = ComputePvalues(tmap, df, 'F', OPTIONS.TestTail);
                    % Units: F
                    DisplayUnits = 'F';
                    
                % === ABSOLUTE MEAN TEST ===
                case 'absmean_param'
                    % EXPLANATIONS:
                    %   Assume the individual samples xi follow a normal distribution with mean "m" and variance "s^2":  X ~ N(m,s^2)
                    %   Then mean(x) is also normal with mean m and variance sm^2 = s^2/N:    mean(X) ~ N(m,s^2/N)
                    %   
                    %   When we apply abs(mean(x)), we are folding this normal distribution to make it positive. 
                    %   Details are discussed here: https://en.wikipedia.org/wiki/Folded_normal_distribution
                    %   If y=|x|, with x~N(m,sm^2), then y has a new distribution with mean my and variance sy^2:
                    %      my = sm*sqrt(2/pi)*exp(-m^2/(2*sm^2)) - m*erf(-m/sqrt(2*sm^2))
                    %         = s/sqrt(N)*sqrt(2/pi)*exp(-m^2/(2*s^2/N)) - m*erf(-m/sqrt(2*s^2/N))
                    %      sy^2 = m^2 + sm^2 - my^2
                    %           = m^2 + s^2/N - my^2
                    %
                    % RESTRICTIONS
                    %   - A and B are normally distributed (same as t-test assumptions)
                    %   - Cannot be applied if an absolute has been applied already, we need the original values

                    % Test to check that there was no abs already applied, we need the relative values
                    if all(mA(:) > 0) && all(mB(:) > 0)
                        bst_report('Error', sProcess, [], ['This test is designed for values that are positive and negative.' 10 'It cannot be applied to values for which we have already discarded the sign.' 10 'If all your measures you are testing are always strictly positive, then use a Student t-test.']);
                        return;
                    end
            
                    % Mean of: abs(mean(A))-abs(mean(B))
                    % mAabs = sA/sqrt(N)*sqrt(2/pi)*exp(-mA^2/(2*sA^2/nA)) - mA*erf(-mA/sqrt(2*sA^2/nA))
                    %       = sqrt(vA./nA.*(2/pi)) .* exp(-mA.^2/(2.*vA./nA)) - mA*erf(-mA./sqrt(2.*vA./nA))
                    mAabs = sqrt(vA./nA.*(2/pi)) .* exp(-mA.^2./(2.*vA./nA)) - mA.*erf(-mA./sqrt(2.*vA./nA));
                    mBabs = sqrt(vB./nB.*(2/pi)) .* exp(-mB.^2./(2.*vB./nB)) - mB.*erf(-mB./sqrt(2.*vB./nB));
                    mAB = mAabs - mBabs;
                    % Variance of: abs(mean(A))-abs(mean(B))
                    vAabs = mA.^2 + vA./nA - mAabs.^2;
                    vBabs = mB.^2 + vB./nB - mBabs.^2;
                    sdAB = sqrt(vAabs + vBabs);
                    S = (abs(mA) - abs(mB) - mAB) ./ sdAB;  %S should be zero mean, unit variance under the null hypothesis

                    % [H,P] = ztest(S,0,1);   m = 0; sigma = 1;
                    % zval = (S - m) ./ (sigma ./ sqrt(length(S)));
                    tmap = S .* sqrt(length(S));
                    % Two-tailed test
                    pmap = 2 * (1/2 * erfc(-1 * -abs(tmap) / sqrt(2)));     % 2 * normcdf(-abs(zval),0,1);
                    % No need to recompute the values on the fly
                    df = [];
                    % Units: z
                    DisplayUnits = 'z';
     
                otherwise
                    error('Not supported yet');
            end
            % Remove values with null variances
            if ~isempty(iNull)
                tmap(iNull) = 0;
                pmap(iNull) = 1;
            end
            
            
        % ===== PAIRED/ONE-SAMPLE TESTS =====
        case {'ttest_paired', 'ttest_onesample', 'ttest_baseline', 'chi2_onesample', 'chi2_onesample_unconstr', 'power_baseline', 'power_baseline_unconstr'}
            % Number of samples must be equal
            if (length(sInputsA) ~= length(sInputsB)) && ismember(OPTIONS.TestType, {'ttest_paired'})
                bst_report('Error', sProcess, [], 'For a paired test, the number of files must be the same in the two groups.');
                return;
            end
            % Compute the mean and variance of (samples A - samples B)
            [StatA, MessagesA] = bst_avg_files(InputSetA, InputSetB, AvgFunction, isAvgVariance, isAvgWeighted, OPTIONS.isMatchRows, OPTIONS.isZeroBad);
            % Add messages to report
            if ~isempty(MessagesA)
                if isempty(StatA)
                    bst_report('Error', sProcess, [], MessagesA);
                    return;
                else
                    bst_report('Warning', sProcess, [], MessagesA);
                end
            end
            % Display progress bar
            bst_progress('start', 'Processes', 'Computing test...');
            % Bad channels and other properties
            switch lower(sInputsA(1).FileType)
                case {'data', 'pdata'}
                    ChannelFlag = StatA.ChannelFlag;
                    isGood = (ChannelFlag == 1);
                case {'results', 'timefreq', 'matrix', 'presults', 'ptimefreq', 'pmatrix'}
                    ChannelFlag = [];
                    isGood = true(size(StatA.mean, 1), 1);
                    isGood(StatA.nGoodSamples < 2) = -1;
            end
            
            % === COMPUTE TEST ===
            % Display progress bar
            bst_progress('start', 'Processes', 'Computing test...');
            % Get results
            mean_diff = StatA.mean(isGood,:,:);
            nA = repmat(StatA.nGoodSamples(isGood,:,:), [1, size(mean_diff,2), size(mean_diff,3)]);
            nB = [];
            % Get variance (if needed)
            if isAvgVariance
                std_diff = sqrt(StatA.var(isGood,:,:));
                % Remove null variances
                iNull = find(std_diff == 0);
                std_diff(iNull) = eps;
            else
                iNull = [];
            end
            
            % Get pre-stimulus baseline (for tests vs baseline)
            if ismember(OPTIONS.TestType, {'ttest_baseline', 'power_baseline', 'power_baseline_unconstr'})
                if ~isempty(Baseline)
                    % Get baseline bounds
                    iBaseline = bst_closest(Baseline, StatA.Time);
                    if (iBaseline(1) == iBaseline(2))
                        bst_report('Error', sProcess, [], 'The baseline must be included in the time window on which you run the test.');
                        return;
                    end
                    iBaseline = iBaseline(1):iBaseline(2);
                else
                    bst_report('Warning', sProcess, [], 'Baseline is not defined, using the entire time definition.');
                    iBaseline = 1:length(TimeVector);
                end
            end
            
            % Compute test statistic
            switch (OPTIONS.TestType)
                case {'ttest_paired', 'ttest_onesample'}
                    % Compute t-test
                    tmap = mean_diff ./ std_diff .* sqrt(nA);
                    df = nA - 1;
                    % Test if the statistics make sense
                    if all(tmap(:) == 0)
                        bst_report('Error', sProcess, [], 'The T-statistics is zero for all the tests.');
                        return;
                    end
                    % Calculate p-values from t-values
                    pmap = ComputePvalues(tmap, df, 't', OPTIONS.TestTail);
                    % Units: t
                    DisplayUnits = 't';
                    
                case {'chi2_onesample', 'chi2_onesample_unconstr'}
                    % https://en.wikipedia.org/wiki/Chi-squared_distribution
                    % =>  If Zi~N(0,1) i=1..n  =>  Q=sum(Zi^2) ~ Chi2(n)
                    % Variable "mean_diff" contains RMS(data)=sqrt(sum(data.^2)/n)   
                    % =>  If data is ~N(0,1)   =>  (mean_diff^2 * n) ~ Chi2(n)
                    tmap = mean_diff .^ 2 .* nA;
                    % Number of degrees of freedom
                    if strcmpi(OPTIONS.TestType, 'chi2_onesample_unconstr')
                        df = 3 * nA;
                    else
                        df = nA;
                    end
                    % Calculate p-values from F-values
                    pmap = ComputePvalues(tmap, df, 'chi2', OPTIONS.TestTail);
                    % Units: t
                    DisplayUnits = 'chi2';

                case 'ttest_baseline'
                    % TEST:  Y = mean_trials(X) 
                    %        t = (Y - mean_time(Y(baseline)) / std_time(Y(baseline)))
                    % Compute variance over baseline (pre-stim interval)
                    meanBaseline = mean(mean_diff(:,iBaseline,:), 2);
                    stdBaseline = std(mean_diff(:,iBaseline,:), 0, 2);
                    % Remove null variances
                    iNull = find(stdBaseline == 0);
                    stdBaseline(iNull) = eps;
                    % Compute t-statistics (formula from wikipedia)
                    tmap = bst_bsxfun(@minus, mean_diff, meanBaseline);
                    tmap = bst_bsxfun(@rdivide, tmap, stdBaseline);
                    df = repmat(length(iBaseline) - 1, size(tmap));
                    % Calculate p-values from t-values
                    pmap = ComputePvalues(tmap, df, 't', OPTIONS.TestTail);
                    % Units: t
                    DisplayUnits = 't';
                    
                case {'power_baseline', 'power_baseline_unconstr'}
                    % TEST:  Y = sum_trials(X^2)
                    %        F = Y / mean_time(Y(baseline))     F~F(Ntrials,Ntrials)
                    % 
                    % The output of bst_avg_files is the RMS of X:  data = sqrt(sum_trials(X^2)/Ntrials)
                    % => Y = data^2 * Ntrials
                    % => F = data^2 / mean(data^2(baseline))
                    
                    % Square the RMS
                    data = mean_diff .^ 2;
                    % Compute mean over baseline 
                    meanBaseline = mean(data(:,iBaseline,:), 2);
                    % Remove null denominators
                    iNull = find(meanBaseline == 0);
                    meanBaseline(iNull) = eps;
                    % Compute F statistic
                    tmap = bst_bsxfun(@rdivide, data, meanBaseline);
                    % Degrees of freedom
                    if strcmpi(OPTIONS.TestType, 'power_baseline_unconstr')
                        df = {3*nA,3*nA};
                    else
                        df = {nA,nA};
                    end
                    % Calculate p-values from F-values
                    pmap = ComputePvalues(tmap, df, 'F', OPTIONS.TestTail);
                    % No need to recompute the values on the fly
                    df = [];
                    % Units: t
                    DisplayUnits = 'F';
                    
                otherwise
                    error('Not supported yet');
            end
            % Remove values with null variances
            if ~isempty(iNull)
                tmap(iNull) = 0;
                pmap(iNull) = 1;
            end
    end

    % Return full matrices
    if all(isGood)
        tmap_full = tmap;
        pmap_full = pmap;
        df_full   = df;
        nA_full   = nA;
        nB_full   = nB;
    else
        tmap_full = zeros(size(StatA.mean));
        tmap_full(isGood,:,:) = tmap;
        if ~isempty(df)
            df_full = zeros(size(StatA.mean));
            df_full(isGood,:,:) = df;
        else
            df_full = [];
        end
        if ~isempty(pmap)
            pmap_full = ones(size(StatA.mean));
            pmap_full(isGood,:,:) = pmap;
        else
            pmap_full = [];
        end
        if ~isempty(nA)
            nA_full = zeros(1,size(StatA.mean,1));
            nA_full(isGood) = nA(1:size(nA,1));
        else
            nA_full = [];
        end
        if ~isempty(nB)
            nB_full = zeros(1,size(StatA.mean,1));
            nB_full(isGood) = nB(1:size(nB,1));
        else
            nB_full = [];
        end
    end
    
    % === CONVERT BACK MATRIX => DATA ===
    % If processing recordings with only some sensor types selected
    if strcmpi(sInputsA(1).FileType, 'data') && strcmpi(OutputType, 'matrix') && ~isempty(OPTIONS.SensorTypes) && ~OPTIONS.isAvgTime && ~OPTIONS.isAvgRow && ~OPTIONS.isAvgFreq
        % Get the list of selected sensors
        dataTypes = strtrim(str_split(OPTIONS.SensorTypes, ',;'));
        % If only major data types were selected: save results in "data" format
        if ~isempty(dataTypes) && all(ismember(dataTypes, {'MEG','EEG','MEG MAG''MEG GRAD','MEG GRAD2','MEG GRAD3','SEEG','ECOG','NIRS'}))
            % Load channel file
            ChannelMat = in_bst_channel(sInputsA(1).ChannelFile);
            % Find channel names in the output row names
            [tmp,iChan,iRow] = intersect({ChannelMat.Channel.Name}, StatA.RowNames);
            % Convert output data matrices
            tmap_tmp = zeros(length(ChannelMat.Channel), size(tmap_full,2), size(tmap_full,3));
            tmap_tmp(iChan,:,:) = tmap_full(iRow,:,:);
            tmap_full = tmap_tmp;
            if ~isempty(pmap_full)
                pmap_tmp = zeros(size(tmap_tmp));
                pmap_tmp(iChan,:,:) = pmap_full(iRow,:,:);
                pmap_full = pmap_tmp;
            end
            if ~isempty(df_full)
                df_tmp = zeros(size(tmap_tmp));
                df_tmp(iChan,:,:) = df_full(iRow,:,:);
                df_full = df_tmp;
            end
            % New channel flag
            tmpChannelFlag = -1 .* ones(length(ChannelMat.Channel), 1);
            if ~isempty(ChannelFlag) && (length(ChannelFlag) == length(iChan))
                tmpChannelFlag(iChan) = ChannelFlag(iRow);
            else
                tmpChannelFlag(iChan) = 1;
            end
            ChannelFlag = tmpChannelFlag;
            % Convert Stat structure
            OutputType = 'data';
            StatA.RowNames = [];
        end
    end
    
    % === OUTPUT STRUCTURE ===
    % Initialize output structure
    sOutput = db_template('statmat');
    sOutput.pmap         = pmap_full;
    sOutput.tmap         = tmap_full;
    sOutput.df           = df_full;
    sOutput.Correction   = 'no';
    sOutput.Type         = OutputType;
    sOutput.ChannelFlag  = ChannelFlag;
    sOutput.Time         = StatA.Time;
    sOutput.ColormapType = 'stat2';
    sOutput.DisplayUnits = DisplayUnits;
    sOutput.nComponents  = StatA.nComponents;
    sOutput.GridAtlas    = StatA.GridAtlas;
    sOutput.Freqs        = StatA.Freqs;
    sOutput.TFmask       = StatA.TFmask;
    % Row names
    if isfield(StatA, 'RowNames') && ~isempty(StatA.RowNames)
        if strcmpi(OutputType, 'matrix')
            sOutput.Description = StatA.RowNames;
        elseif strcmpi(OutputType, 'timefreq')
            sOutput.RowNames = StatA.RowNames;
        end
    end
    % Save options
    sOutput.Options = OPTIONS;
    % Save the number of good samples used for both sets
    sOutput.Options.nGoodSamplesA = nA_full;
    sOutput.Options.nGoodSamplesB = nB_full;
end


%% ===== COMPUTE P-VALUES ====
function p = ComputePvalues(t, df, TestDistrib, TestTail)
    % Default: two-tailed tests
    if (nargin < 4) || isempty(TestTail)
        TestTail = 'two';
    end
    % Default: F-distribution
    if (nargin < 3) || isempty(TestDistrib)
        TestDistrib = 'f';
    end
    % Nothing to test
    if strcmpi(TestTail, 'no')
        p = zeros(size(t));
        return;
    end
    
    % Different distributions
    switch lower(TestDistrib)
        % === T-TEST ===
        case 't'
            % Calculate p-values from t-values 
            switch (TestTail)
                case 'one-'
                    % Inferior one-tailed t-test:   p = tcdf(t, df);
                    % Equivalent without the statistics toolbox (FieldTrip formula)            
                    p = 0.5 .* ( 1 + sign(t) .* betainc( t.^2 ./ (df + t.^2), 0.5, 0.5.*df ) );
                case 'two'
                    % Two-tailed t-test:     p = 2 * (1 - tcdf(abs(t),df));
                    % Equivalent without the statistics toolbox
                    p = betainc( df ./ (df + t .^ 2), df./2, 0.5);
                    % FieldTrip equivalent: p2 = 1 - betainc( t.^2 ./ (df + t.^2), 0.5, 0.5.*df );
                case 'one+'
                    % Superior one-tailed t-test:    p = 1 - tcdf(t, df);
                    % Equivalent without the statistics toolbox (FieldTrip formula)
                    p = 0.5 .* ( 1 - sign(t) .* betainc( t.^2 ./ (df + t.^2), 0.5, 0.5.*df ) );
            end
            
        % === F-TEST ===
        case 'f'
            v1 = df{1};
            v2 = df{2};
            % Evaluate for which values we can compute something
            k = ((t > 0) & ~isinf(t) & (v1 > 0) & (v2 > 0));
            % Initialize returned p-values
            p = ones(size(t));                    
            % Calculate p-values from F-values 
            switch (TestTail)
                case 'one-'
                    % Inferior one-tailed F-test
                    % p = fcdf(t, v1, v2);
                    p(k) = 1 - betainc(v2(k)./(v2(k) + v1(k).*t(k)), v2(k)./2, v1(k)./2);
                case 'two'
                    % Two tailed F-test
                    % p = 2*min(fcdf(F,df1,df2),fpval(F,df1,df2))
                    p(k) = 2 * min(...
                            1 - betainc(v2(k)./(v2(k) + v1(k).*t(k)), v2(k)./2, v1(k)./2), ...
                            1 - betainc(v1(k)./(v1(k) + v2(k)./t(k)), v1(k)./2, v2(k)./2));
                case 'one+'
                    % Superior one-tailed F-test
                    % p = fpval(t, v1, v2);
                    %   = fcdf(1/t, v2, v1);
                    p(k) = 1 - betainc(v1(k)./(v1(k) + v2(k)./t(k)), v1(k)./2, v2(k)./2);
            end
            
        % === CHI2-TEST ===
        case 'chi2'
            % Calculate p-values from Chi2-values 
            %   chi2cdf(x,n) = gammainc(t/2, n/2)
            switch (TestTail)
                case 'one-'
                    % Inferior one-tailed Chi2-test:    p = gammainc(t./2, df./2);
                    error('Not relevant.');
                case 'two'
                    % Two-tailed Chi2-test
                    error('Not relevant.');
                case 'one+'
                    % Superior one-tailed Chi2-test:    p = 1 - gammainc(t./2, df./2);
                    p = 1 - gammainc(t./2, df./2);
            end
    end
end


    
    