function varargout = process_test_permutation2( varargin )
% PROCESS_TEST_PERMUTATION2: Permutation two-sample tests (independent).

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
% Authors: Francois Tadel, Dimitrios Pantazis, 2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Permutation test: Independent';
    sProcess.Category    = 'Stat2';
    sProcess.SubGroup    = 'Test';
    sProcess.Index       = 104;
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
    sProcess.options.iszerobad.Comment = 'Exclude the zero values from the computation';
    sProcess.options.iszerobad.Type    = 'checkbox';
    sProcess.options.iszerobad.Value   = 1;
    % === OUTPUT COMMENT
    sProcess.options.Comment.Comment = 'Comment (empty=default): ';
    sProcess.options.Comment.Type    = 'text';
    sProcess.options.Comment.Value   = '';
    
    % === TEST: title
    sProcess.options.test_title.Comment    = '<BR><B><U>Test statistic</U></B>:';
    sProcess.options.test_title.Type       = 'label';
    % === TEST: type
    sProcess.options.test_type.Comment = {['<B>Student''s t-test &nbsp;&nbsp;(equal variance)</B> <BR>t = (mean(A)-mean(B)) / (Sx * sqrt(1/nA + 1/nB))<BR>' ...
                                           'Sx = sqrt(((nA-1)*var(A) + (nB-1)*var(B)) / (nA+nB-2))'], ...
                                          ['<B>Student''s t-test &nbsp;&nbsp;(unequal variance)</B> <BR>', ...
                                           't = (mean(A)-mean(B)) / sqrt(var(A)/nA + var(B)/nB)'], ...
                                          ['<B>Absolute mean test:</B> &nbsp;&nbsp; <FONT COLOR="#777777">(works with unconstrained sources)</FONT><BR>' ...
                                           'T = (|mean(A)|-|mean(B)|) / sqrt(|var(A)|/nA + |var(B)|/nB)']; ...
                                          ...  ['<B>Wilcoxon rank-sum test</B> <BR>', ...
                                          ...  'R = tiedrank([A,B]), &nbsp;&nbsp; W = sum(R(1:nA))']; ...
                                          'ttest_equal', 'ttest_unequal', 'absmean'}; % , 'wilcoxon'};
    sProcess.options.test_type.Type    = 'radio_label';
    sProcess.options.test_type.Value   = 'ttest_equal';
    
    % ===== STATISTICAL TESTING OPTIONS =====
    sProcess.options.label2.Comment  = '<BR><B><U>Statistical testing (Monte-Carlo)</U></B>:';
    sProcess.options.label2.Type     = 'label';
    % === NUMBER OF RANDOMIZATIONS
    sProcess.options.randomizations.Comment = 'Number of randomizations:';
    sProcess.options.randomizations.Type    = 'value';
    sProcess.options.randomizations.Value   = {1000, '', 0};
    % === TAIL FOR THE TEST STATISTIC
    sProcess.options.tail.Comment  = {'One-tailed (-)', 'Two-tailed', 'One-tailed (+)', ''; ...
                                      'one-', 'two', 'one+', ''};
    sProcess.options.tail.Type     = 'radio_linelabel';
    sProcess.options.tail.Value    = 'two';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = process_test_parametric2('FormatComment', sProcess);
    Comment = ['Perm ' Comment];
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
    Randomizations = sProcess.options.randomizations.Value{1};
    % Invalid test/tail combinations
    if ismember(OPTIONS.TestType, {'ttest_onesample'}) && OPTIONS.isAbsolute && ismember(OPTIONS.TestTail, {'two', 'one-'})
        bst_report('Warning', sProcess, [], 'Testing |X|>0: Using a positive one-tailed test (one+) instead.');
        OPTIONS.TestTail = 'one+';
    elseif strcmpi(OPTIONS.TestType, 'chi2_onesample') && ismember(OPTIONS.TestTail, {'two', 'one-'})
        bst_report('Warning', sProcess, [], 'Testing |X|>0: Using a positive one-tailed test (one+) instead.');
        OPTIONS.TestTail = 'one+';
    elseif strcmpi(OPTIONS.TestType, 'signtest') && ismember(OPTIONS.TestTail, {'two', 'one-'})
        bst_report('Warning', sProcess, [], 'The sign test statistic produces positive values only: Using a positive one-tailed test (one+) instead.');
        OPTIONS.TestTail = 'one+';
    end


    % ===== CHECK INPUT FILES =====
    % Make sure that file type is indentical for both sets
    if ~isempty(sInputsA) && ~isempty(sInputsB) && ~strcmpi(sInputsA(1).FileType, sInputsB(1).FileType)
        bst_report('Error', sProcess, [], 'Cannot process inputs from different types.');
        return;
    end
    % Check the number of files in input
    if (length(sInputsA) < 2)
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
    % Concatenante values in the 4th dimension
    OPTIONS.Dim = 4;
    % Set all the bad values to 0
    OPTIONS.isBadZero = 1;
    % Call extraction process: FilesA
    [sDataA, OutputType, matName] = process_extract_values('Extract', sProcess, sInputsA, OPTIONS);
    if isempty(sDataA)
        bst_report('Error', sProcess, [], 'No data read from FilesA.');
        return;
    end
    % Read FilesB
    sDataB = process_extract_values('Extract', sProcess, sInputsB, OPTIONS);
    if isempty(sDataB)
        bst_report('Error', sProcess, [], 'No data read from FilesB.');
        return;
    elseif (size(sDataA.(matName),1) ~= size(sDataB.(matName),1)) || (size(sDataA.(matName),2) ~= size(sDataB.(matName),2)) || (size(sDataA.(matName),3) ~= size(sDataB.(matName),3))
        bst_report('Error', sProcess, [], 'Files A and B do not have the same number of signals or time samples.');
        return;
    end
% WARNING ONLY APPLIES TO PARAMETRIC TESTS
%     % Time-frequency: Warning if processing power
%     if strcmpi(sInputsA(1).FileType, 'timefreq') && isfield(sDataA, 'Measure') && isequal(sDataA.Measure, 'power')
%         bst_report('Warning', sProcess, [], ['You are testing power values, while a more standard analysis is to test the magnitude (ie. sqrt(power)).' 10 ...
%             'Option #1: Recompute the time-frequency maps using the option "Measure: Magnitude".' 10 ...
%             'Option #2: Run the process "Extract > Measure from complex values", with option "Magntiude".']);
%     end

    % ===== UNCONSTRAINED SOURCES =====
    % Detect if the source model is unconstrained
    isUnconstrained = panel_scout('isUnconstrained', sDataA);
    % Do not allow unconstrained sources without a norm
    if isUnconstrained && ~OPTIONS.isAbsolute
        % Unconstrained models: Ok if using 
        if strcmpi(OPTIONS.TestType, 'absmean') % && (sDataA.nComponents == 3)
            OPTIONS.TestType = 'absmean_unconstr';
        else
            bst_report('Error', sProcess, [], ['Cannot run this test on unconstrained sources:' 10 'you must compute the norm of the three orientations first.']);
            return;
        end
    end

    
    % === COMPUTE TEST ===
    % Run the permutation test
    [pmap, tmap, nA, nB] = bst_permtest(sDataA.(matName), sDataB.(matName), OPTIONS.TestType, OPTIONS.Dim, Randomizations, OPTIONS.TestTail, OPTIONS.isZeroBad);
    % Finished processing
    bst_progress('text', 'Saving the results...');

    % Bad channels: For recordings, keep only the channels that are good in BOTH A and B sets
    switch lower(sInputsA(1).FileType)
        case 'data'
            ChannelFlag = sDataA.ChannelFlag;
            ChannelFlag(sDataB.ChannelFlag == -1) = -1;
        case {'results', 'timefreq', 'matrix'}
            ChannelFlag = [];
    end
    
    % === DISPLAYED UNITS ===
    switch (OPTIONS.TestType)
        case 'ttest_equal',      DisplayUnits = 't';
        case 'ttest_unequal',    DisplayUnits = 't';
        case 'ttest_paired',     DisplayUnits = 't';
        case 'signtest',         DisplayUnits = 'N';
        case 'wilcoxon_paired',  DisplayUnits = 'W';
        case 'absmean',          DisplayUnits = 'T';
        case 'absmean_unconstr', DisplayUnits = 'T';
        % case 'wilcoxon',        DisplayUnits = 'W';
        otherwise,              error('Invalid statistic.');
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
            iChannels = channel_find(ChannelMat.Channel, OPTIONS.SensorTypes);
            % Convert output data matrices
            % tmap
            tmap_tmp = zeros(length(ChannelMat.Channel), size(tmap,2), size(tmap,3));
            tmap_tmp(iChannels,:,:) = tmap;
            tmap = tmap_tmp;
            % pmap
            pmap_tmp = zeros(size(tmap_tmp));
            pmap_tmp(iChannels,:,:) = pmap;
            pmap = pmap_tmp;
            % nA
            if ~isempty(nA)
                nA_tmp = zeros(size(tmap_tmp));
                nA_tmp(iChannels,:,:) = nA;
                nA = nA_tmp;
            end
            % nB
            if ~isempty(nB)
                nB_tmp = zeros(size(tmap_tmp));
                nB_tmp(iChannels,:,:) = nB;
                nB = nB_tmp;
            end
            % New channel flag
            tmpChannelFlag = -1 .* ones(length(ChannelMat.Channel), 1);
            if ~isempty(ChannelFlag) && (length(ChannelFlag) == length(iChannels))
                tmpChannelFlag(iChannels) = ChannelFlag;
            else
                tmpChannelFlag(iChannels) = 1;
            end
            ChannelFlag = tmpChannelFlag;
            % Convert Stat structure
            OutputType = 'data';
            sDataA.RowNames = [];
        end
    end
    
    % === OUTPUT STRUCTURE ===
    % Initialize output structure
    sOutput = db_template('statmat');
    sOutput.pmap         = pmap;
    sOutput.tmap         = tmap;
    sOutput.df           = [];
    sOutput.Correction   = 'no';
    sOutput.Type         = OutputType;
    sOutput.ChannelFlag  = ChannelFlag;
    sOutput.Time         = sDataA.Time;
    sOutput.ColormapType = 'stat2';
    sOutput.DisplayUnits = DisplayUnits;
    if strcmpi(OPTIONS.TestType, 'absmean_unconstr')
        sOutput.nComponents = 1;
    elseif isfield(sDataA, 'nComponents')
        sOutput.nComponents = sDataA.nComponents;
    end
    if isfield(sDataA, 'GridAtlas')
        sOutput.GridAtlas = sDataA.GridAtlas;
    end
    if isfield(sDataA, 'Freqs')
        sOutput.Freqs = sDataA.Freqs;
    end
    if isfield(sDataA, 'TFmask')
        sOutput.TFmask = sDataA.TFmask;
    end
    % Row names
    if isfield(sDataA, 'Description') && ~isempty(sDataA.Description)
        RowNames = sDataA.Description;
    elseif isfield(sDataA, 'RowNames') && ~isempty(sDataA.RowNames)
        RowNames = sDataA.RowNames;
    else
        RowNames = [];
    end
    if ~isempty(RowNames)
        if strcmpi(OutputType, 'matrix')
            sOutput.Description = RowNames;
        elseif strcmpi(OutputType, 'timefreq')
            sOutput.RowNames = RowNames;
        end
    end
    % Save options
    sOutput.Options = OPTIONS;
    % Save the number of good samples used for both sets: 
    % In compressed format (keeping only one value per row, if all the other dimensions are the same)
    if isequal(nA(1:size(nA,1))', mean(mean(nA,2),3))
        sOutput.Options.nGoodSamplesA = nA(1:size(nA,1))';
        sOutput.Options.nGoodSamplesB = nB(1:size(nB,1))';
    % Or saving the full list of good samples 
    else
        sOutput.Options.nGoodSamplesA = nA;
        sOutput.Options.nGoodSamplesB = nB;
    end
end


    
    