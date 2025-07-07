function varargout = process_test_normative( varargin )
% PROCESS_TEST_NORMATIVE: Compare PSDs of each file A with the distribution of PSDs from files B
% For testing the normality of the residuals, the Shapiro-Wilk test is used.
% Careful, the test is less appropriate for large sample sizes (n>=50) [1] and may be too conservative.
%
% References:
%     [1] Mishra, Prabhaker, Chandra M Pandey, Uttam Singh, Anshul Gupta, Chinmoy Sahu, and Amit Keshri,
%         Descriptive Statistics and Normality Tests for Statistical Data,
%         Annals of Cardiac Anaesthesia 22, no. 1 (2019): 67–72. https://doi.org/10.4103/aca.ACA_157_18.

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
% Authors: Pauline Amrouche, 2024
%          Raymundo Cassani, 2024-2025
%          Lindsey Power,    2024

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Compare (A) to normative PSDs (B)';
    sProcess.FileTag     = '';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Test';
    sProcess.Index       = 110;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/DeviationMaps';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % Options: Log values
    sProcess.options.islog.Comment       = 'Use log10 values';
    sProcess.options.islog.Type          = 'checkbox';
    sProcess.options.islog.Value         = 1;

    % Options: Normal distribution
    sProcess.options.istest.Comment    = 'Perform deviation test (otherwise return z-scores)';
    sProcess.options.istest.Type       = 'checkbox';
    sProcess.options.istest.Value      = 1;
    sProcess.options.istest.Controller = 'Test';

    % Options: Test section title
    sProcess.options.test_title.Comment  = '<BR><B><U>Deviation test </U></B>:';
    sProcess.options.test_title.Type     = 'label';
    sProcess.options.test_title.Class    = 'Test';

    % Options : Select deviation level
    sProcess.options.devlevel.Comment    = 'Deviation level (range 0-1):';
    sProcess.options.devlevel.Type       = 'value';
    sProcess.options.devlevel.Value      = {0.05, '', 2};
    sProcess.options.devlevel.Class      = 'Test';

    % Options: Normal distribution
    sProcess.options.isnormal.Comment    = 'Assume normal distribution of residuals';
    sProcess.options.isnormal.Type       = 'checkbox';
    sProcess.options.isnormal.Value      = 0;
    sProcess.options.isnormal.Controller = 'Normal';
    sProcess.options.isnormal.Class      = 'Test';

    % Options: Shapiro-Wilk test for normality
    sProcess.options.shapiro.Comment     = 'Test for normality of residuals (Shapiro-Wilk)';
    sProcess.options.shapiro.Type        = 'checkbox';
    sProcess.options.shapiro.Value       = 1;
    sProcess.options.shapiro.Class       = 'Normal';

    % === Frequency output
    % Options: Frequency definition title
    sProcess.options.freq_title.Comment    = '<BR><B><U>Frequency definition</U></B>:';
    sProcess.options.freq_title.Type       = 'label';
    % Options: Frequency definition
    sProcess.options.freqout.Comment   = {'Same as input', 'Frequency range', 'Frequency bands', 'Frequency definition:'; ...
                                          'input', 'range', 'bands', ''};
    sProcess.options.freqout.Type      = 'radio_linelabel';
    sProcess.options.freqout.Value     = 'input';
    sProcess.options.freqout.Controller.range = 'range';
    sProcess.options.freqout.Controller.bands = 'bands';
    % === Individual frequency range
    sProcess.options.freqrange.Comment = 'Frequency range: ';
    sProcess.options.freqrange.Type    = 'freqrange_static';   % 'freqrange'
    sProcess.options.freqrange.Value   = {[1 150], 'Hz', 1};
    sProcess.options.freqrange.Class   = 'range';
    % === Frequency bands
    sProcess.options.freqbands.Comment = '';
    sProcess.options.freqbands.Type    = 'groupbands';
    sProcess.options.freqbands.Value   = bst_get('DefaultFreqBands');
    sProcess.options.freqbands.Class   = 'bands';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function sOutput = Run(sProcess, sInputsA, sInputsB)  %#ok<DEFNU>
    % Initialize output
    sOutput = cell(1, length(sInputsA));

    % Fetch user options
    OPTIONS.IsLog         = sProcess.options.islog.Value;
    OPTIONS.FreqOut       = sProcess.options.freqout.Value;
    OPTIONS.FreqRange     = sProcess.options.freqrange.Value{1};
    OPTIONS.FreqBands     = sProcess.options.freqbands.Value;
    OPTIONS.DevLevel      = sProcess.options.devlevel.Value{1};
    OPTIONS.IsTest        = sProcess.options.istest.Value;
    OPTIONS.IsNormal      = sProcess.options.isnormal.Value;
    OPTIONS.TestNormality = sProcess.options.shapiro.Value;

    % FilesA in FilesB
    Lia = ismember({sInputsA.FileName}, {sInputsB.FileName});
    sInputsUnique = [sInputsB, sInputsA(~Lia)];

    % Validate inputs
    [errMsg, iInputErr, nRows, Freqs] = CheckInputs(sInputsUnique);
    if ~isempty(errMsg) && ~isempty(iInputErr)
        bst_report('Error', sProcess, sInputsUnique(iInputErr), errMsg);
        return
    end

    % Frequency options
    errMsg = '';
    switch OPTIONS.FreqOut
        case 'bands'
            if iscell(Freqs)
                requestedBands = cellfun(@(x,y,z) strjoin({x,y,z}, ';'), OPTIONS.FreqBands(:,1), OPTIONS.FreqBands(:,2), OPTIONS.FreqBands(:,3), 'UniformOutput', 0);
                availableBands = cellfun(@(x,y,z) strjoin({x,y,z}, ';'), Freqs(:,1), Freqs(:,2), Freqs(:,3), 'UniformOutput', 0);
                [Lia,Locb] = ismember(requestedBands, availableBands);
                if ~all(Lia)
                    errMsg = 'Not all requested bands are defined in the frequency bands of the input files.';
                end
                freqMask = false(1, size(Freqs,1));
                freqMask(Locb) = true;
                OPTIONS.FreqBands = [];
            else
                tmp = str2num(strjoin(OPTIONS.FreqBands(:,2), ','));
                requestedBandsLimits(1) = min(tmp);
                requestedBandsLimits(2) = max(tmp);
                if requestedBandsLimits(1) < Freqs(1) || requestedBandsLimits(2) > Freqs(end)
                    errMsg = 'Frequency bands must be defined inside the frequency range of the input files.';
                end
                freqMask = true(1, size(OPTIONS.FreqBands,1));
            end

        case 'range'
            OPTIONS.FreqBands = [];
            if iscell(Freqs)
                errMsg = 'Cannot use frequency range ouput if input files are defined in frequency bands.';
            else
                if OPTIONS.FreqRange(1) < Freqs(1) || OPTIONS.FreqRange(2) > Freqs(end)
                    errMsg = 'Frequency bands must be defined inside the frequency range of the input files.';
                end
                % find closest
                iFreqRange1 = bst_closest(OPTIONS.FreqRange(1), Freqs);
                iFreqRange2 = bst_closest(OPTIONS.FreqRange(2), Freqs);
                freqMask = false(1, length(Freqs));
                freqMask(iFreqRange1:iFreqRange2) = true;
            end

        case 'input'
            % Keep all frequencies
            OPTIONS.FreqBands = [];
            freqMask = true(1, length(Freqs));

    end
    if ~isempty(errMsg)
        bst_report('Error', sProcess, sInputsB(1), errMsg);
        return
    end

    % Initialize array to hold distributions
    tfDataB = zeros(nRows, sum(freqMask), length(sInputsB));
    % Load normative values
    for iInputB = 1 : length(sInputsB)
        % Load and preprocess timefreq file
        timefreqMat = PreProcessInput(sInputsB(iInputB), freqMask, OPTIONS);
        tfDataB(:,:,iInputB) = squeeze(timefreqMat.TF);
    end
    % Compute normative distribution
    normDistrib = ComputeNormDistrib(sProcess, tfDataB, OPTIONS);
    clear tfDataB
    % Compare each SubjectA PSD to the normative distribution
    for iSubA = 1:length(sInputsA)
        % Load and preprocess timefreq file
        timefreqMat = PreProcessInput(sInputsA(iSubA), freqMask, OPTIONS);
        % Compute significance deviation map, replace TF field
        timefreqMat = CompareToNormDistrib(timefreqMat, normDistrib, OPTIONS);
        % Create the output file
        sOutput{iSubA} = SaveData(sInputsA(iSubA), sInputsB, timefreqMat, OPTIONS);
    end
end


%% ===== FORMAT FILE COMMENT =====
function comment = GetComment(tfMat, options)
    % Initialize suffix for file comment
    comment_suffix = '';
    if options.IsLog
        comment_suffix = [comment_suffix, ' log'];
    end
    if options.IsNormal
        comment_suffix = [comment_suffix, ' normal'];
    end
    % Check that the options are valid and update the comment suffix
    switch options.FreqOut
        case 'bands'
            comment_suffix = [comment_suffix, ' bands'];

        case 'range'
            comment_suffix = [comment_suffix, sprintf(' %d-%dHz', options.FreqRange(1), options.FreqRange(2))];

        case 'input'
            if iscell(tfMat.Freqs)
                comment_suffix = [comment_suffix, ' bands'];
            end
    end
    % Format the comment suffix
    if ~isempty(comment_suffix)
        comment_suffix = ['| ' comment_suffix];
    end
    % Deviation test performed
    if options.IsTest
        test_suffix = sprintf('devLevel (%.2f) %s', options.DevLevel);
    else
        test_suffix = sprintf('z-scores');
    end
    % Build comment
    comment = sprintf('comp. to norm: %s %s', test_suffix, comment_suffix);
end


%% ===== PREPROCESS INPUT DATA =====
% Load and preprocess timefreq file
function timefreqMat = PreProcessInput(sInput, freqMask, options)
    % Load PSD file
    timefreqMat = in_bst_timefreq(sInput.FileName, 1);
    % Extract frequency bands (input has Frequency vector, output resquested in Bands)
    if ~isempty(options.FreqBands)
        timefreqMat = process_tf_bands('Compute', timefreqMat, options.FreqBands, []);
    end
    % Keep requested frequencies
    timefreqMat.TF = timefreqMat.TF(:, 1, freqMask);
    if iscell(timefreqMat.Freqs)
        timefreqMat.Freqs = timefreqMat.Freqs(freqMask, :);
    else
        timefreqMat.Freqs = timefreqMat.Freqs(freqMask);
    end
    % If log values, apply log
    if options.IsLog
        timefreqMat.TF = log10(timefreqMat.TF);
    end
end


%% ===== VALIDATE INPUT FILES =====
% Check that all files are PSD files, have same DataType, have same space, and have same frequency definition
function [errMsg, iInputErr, nRows, Freqs] = CheckInputs(sInputs)
    errMsg = '';
    nRows  = [];
    Freqs  = [];
    % Files must: be PSD, have same DataType, have same space, and have same frequency definition
    for iInput = 1 : length(sInputs)
        iInputErr = iInput;
        timefreqMat = in_bst_timefreq(sInputs(iInput).FileName, 0, 'Method', 'RowNames', 'DataType', 'HeadModelType', 'SurfaceFile', 'HeadModelFile', 'Freqs');
        if ~strcmpi(timefreqMat.Method, 'psd')
            errMsg = 'Input files must be PSD files.';
            return
        end
        %  Verify files that must be common
        if iInput == 1
            % Get reference fields
            refDataType = timefreqMat.DataType;
            switch refDataType
                case {'data', 'matrix'}
                    refCommonSpaceFile = timefreqMat.RowNames;
                case 'results'
                    refHeadModelType = timefreqMat.HeadModelType;
                    switch refHeadModelType
                        case 'surface'
                            refCommonSpaceFile = timefreqMat.SurfaceFile;
                        case 'volume'
                            refCommonSpaceFile = timefreqMat.HeadModelFile;
                        otherwise
                            errMsg = ['HeadModel of type ' refHeadModelType ' is not supported.'];
                            return
                    end
            end
            refRowNames = timefreqMat.RowNames;
            nRows = length(refRowNames);
            refFreqs = timefreqMat.Freqs;

        else
            % Check against reference DataType
            if ~strcmpi(timefreqMat.DataType, refDataType)
                errMsg = 'All PSD files must share the same "DataType"';
                return
            end
            % PSD files must be computed in the same modality and space
            switch timefreqMat.DataType
                case {'data', 'matrix'}
                    if ~isequal(refCommonSpaceFile, timefreqMat.RowNames)
                        errMsg = 'PSD files from sensors (or matrices) must share the same channel names.';
                        return
                    end
                case 'results'
                    switch timefreqMat.HeadModelType
                        case 'surface'
                            if ~isequal(refCommonSpaceFile, timefreqMat.SurfaceFile)
                                errMsg = 'PSD files from surface sources must share the same surface file.';
                                return
                            end
                        case 'volume'
                            if ~isequal(refCommonSpaceFile, timefreqMat.RowNames)
                                errMsg = 'PSD files from volume sources must share the head model (volume grid) file.';
                                return
                            end
                        otherwise
                            errMsg = ['HeadModel of type ' timefreqMat.HeadModelType ' is not supported.'];
                            return
                    end
            end
            % Check frequency definition
            if isequal(size(timefreqMat.Freqs), size(refFreqs))
                if iscell(refFreqs)
                    for iBand = 1 : size(timefreqMat.Freqs, 1)
                        if ~strcmpi(strjoin(timefreqMat.Freqs(iBand, :)), strjoin(refFreqs(iBand, :)))
                            errMsg = 'PSD files have different frequency band definition.';
                            return
                        end
                    end
                else
                    if abs(sum(timefreqMat.Freqs - refFreqs)) > 1e-6
                        errMsg = 'PSD files have different frequency axes.';
                        return
                    end
                end
            else
                errMsg = 'PSD files must have the same frequency definition.';
                return
            end
        end
    end
    Freqs = refFreqs;
    iInputErr = [];
end


%% ===== COMPUTE NORMATIVE DISTRIBUTION =====
% Compute statistics for normative distribution
function normDistrib = ComputeNormDistrib(sProcess, norm_values, options)
    [nRows, nFreqs, ~] = size(norm_values);
    % Compute the mean and std of the normative values, across subjects
    normDistrib.norm_means = mean(norm_values, 3);
    normDistrib.norm_stds  = std(norm_values, 0, 3);

    % Compute the residuals (z-scores) for normative values
    residuals = (norm_values - normDistrib.norm_means) ./ normDistrib.norm_stds;

    if options.IsNormal && options.TestNormality
        % Assuming that the residuals are normally distributed
        % We can test the normality of the residuals using the Shapiro-Wilk test
        % Results are displayed in the report
        p_shapiro   = zeros(nRows, nFreqs);
        % Compute the Shapiro-Wilk test for normality
        for iRow = 1:nRows
            for iFreq = 1:nFreqs
                [~, p] = swtest(residuals(iRow, iFreq, :));
                p_shapiro(iRow, iFreq)   = p;
            end
        end
        % Report the results of normality test
        bst_report('Info', sProcess, [], ['Shapiro-Wilk test for normality of residuals:', 10, ...
                   sprintf('Significant at p &lt 0.05 : %d/%d', sum(p_shapiro < 0.05, "all"), nRows*nFreqs), 10,...
                   sprintf('Significant at p &lt 0.1 : %d/%d',  sum(p_shapiro < 0.1,  "all"), nRows*nFreqs)]);
    end

    % Compute the percentiles of the distribution of residuals
    if options.IsNormal
        normDistrib.norm_percentile = norminv(1-options.DevLevel/2);
    else
        normDistrib.percentiles = prctile(residuals, [(options.DevLevel/2)*100, (1-(options.DevLevel/2))*100], 3);
    end
end


%% ===== COMPARE TO NORMATIVE DISTRIBUTION =====
% Compute the deviation map wrt the normative distribution
function timefreqMat = CompareToNormDistrib(timefreqMat, normDistrib, options)
    % Compute the z-scores
    z_scores = (squeeze(timefreqMat.TF) - normDistrib.norm_means) ./ normDistrib.norm_stds;
    if options.IsTest
        % Identify z_scores that are significantly different from the normative distribution
        if options.IsNormal
            signif_neg = (z_scores < -(normDistrib.norm_percentile))*(-1);
            signif_pos = (z_scores > normDistrib.norm_percentile);
        else
            signif_neg = (z_scores < normDistrib.percentiles(:, :, 1))*(-1);
            signif_pos = (z_scores > normDistrib.percentiles(:, :, 2));
        end
        outValue = signif_neg + signif_pos;
        outUnit  = 'significant deviation';
    else
        outValue = z_scores;
        outUnit  = 'z';
    end
    % Restore time dimenstion
    timefreqMat.TF = permute(outValue, [1,3,2]);
    timefreqMat.DisplayUnits = outUnit;
end


%% ===== SAVE TEST RESULTS =====
function output = SaveData(sInputA, sInputsB, tfMat, options)
    % Add comment, change filename and save
    tfMat.ColormapType = 'stat2';
    tfMat.Measure      = 'other';
    % Get file comment from options
    tfMat.Comment = GetComment(tfMat, options);

    % History
    tfMat = bst_history('add', tfMat, 'comp2norm', sprintf('File compared to normative: %s', sInputA.FileName));
    if options.IsTest
        tfMat = bst_history('add', tfMat, 'comp2norm', sprintf('devLevel = %.2f, isNorm = %d, isLog10 = %d', options.DevLevel, options.IsNormal, options.IsLog));
    else
        tfMat = bst_history('add', tfMat, 'comp2norm', sprintf('z-scores, isLog10 = %d', options.IsLog));
    end
    % History: List files used for normative
    tfMat = bst_history('add', tfMat, 'comp2norm', 'List of files used for normative distribution:');
    for i = 1:length(sInputsB)
        tfMat = bst_history('add', tfMat, 'comp2norm', [' - ' sInputsB(i).FileName]);
    end
    % Output filename
    [originalPath, originalBase, originalExt] = bst_fileparts(file_fullpath(sInputA.FileName));
    output = bst_fullfile(originalPath, [originalBase, '_' 'comp2norm', originalExt]);
    output = file_unique(output);
    % Save the file
    bst_save(output, tfMat, 'v6');
    db_add_data(sInputA.iStudy, output, tfMat);
end