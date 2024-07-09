function varargout = process_comp_to_normative( varargin )
% PROCESS_COMP_TO_NORMATIVE: Compare PSDs of each file in A with the distribution of PSDs in B
% For testing the normality of the residuals, the Shapiro-Wilk test is used. 
% Careful, the test is less appropriate for large sample sizes (n>=50) [1] and may be too conservative.
%
% [1] Mishra, Prabhaker, Chandra M Pandey, Uttam Singh, Anshul Gupta, Chinmoy Sahu, and Amit Keshri. ‘Descriptive Statistics and Normality Tests for Statistical Data’. Annals of Cardiac Anaesthesia 22, no. 1 (2019): 67–72. https://doi.org/10.4103/aca.ACA_157_18.
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
% Authors: Pauline Amrouche, Raymundo Cassani, 2024
%                
%
eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Compare (A) to normative PSDs (B)';
    sProcess.FileTag     = '';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Other';
    sProcess.Index       = 175;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    sProcess.isPaired    = 0;
    sProcess.isSeparator = 0;

    % Options: Condition in which the data will be saved
    sProcess.options.intraCond.Comment = 'Condition in which the data will be saved:';
    sProcess.options.intraCond.Type    = 'text';
    sProcess.options.intraCond.Value   = 'comp_to_normative';
    
    % Options: Log values
    sProcess.options.log.Comment = 'Use log values';
    sProcess.options.log.Type    = 'checkbox';
    sProcess.options.log.Value   = 1;

    % Options : Select p-value
    sProcess.options.pvalue.Comment = 'Deviation level (range 0-1):';
    sProcess.options.pvalue.Type    = 'value';
    sProcess.options.pvalue.Value   = {0.05, '', 3};

    % Options: Normal distribution
    sProcess.options.normal.Comment    = 'Assume normal distribution of residuals';
    sProcess.options.normal.Type       = 'checkbox';
    sProcess.options.normal.Value      = 0;
    sProcess.options.normal.Controller = 'Normal';
    % Options : Shapiro-Wilk test for normality
    sProcess.options.shapiro.Comment = 'Test for normality of residuals (Shapiro-Wilk)';
    sProcess.options.shapiro.Type    = 'checkbox';
    sProcess.options.shapiro.Value   = 1;
    sProcess.options.shapiro.Class   = 'Normal';

    % Options: Frequencies
    % === Frequency type
    sProcess.options.freqtype.Comment = {'Same as input', 'Individual Frequencies', 'Frequency bands', 'Frequency definition:'; 'input', 'indiv', 'band', ''};
    sProcess.options.freqtype.Type    = 'radio_linelabel';
    sProcess.options.freqtype.Value   = 'input';
    sProcess.options.freqtype.Controller.indiv = 'Indiv';
    sProcess.options.freqtype.Controller.band = 'Band';
    % === Individual frequencies range
    sProcess.options.freqrange.Comment = 'Frequency range for analysis: ';
    sProcess.options.freqrange.Type    = 'freqrange_static';   % 'freqrange'
    sProcess.options.freqrange.Value   = {[1 150], 'Hz', 1};
    sProcess.options.freqrange.Class   = 'Indiv';
    % === Frequency bands
    sProcess.options.freqbands.Comment = '';
    sProcess.options.freqbands.Type    = 'groupbands';
    sProcess.options.freqbands.Value   = bst_get('DefaultFreqBands');
    sProcess.options.freqbands.Class   = 'Band';

end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end

%% ===== RUN =====
function sOutput = Run(sProcess, sInputsA, sInputsB)  %#ok<DEFNU>

    bst_report('Start', [sInputsA, sInputsB]);

    % Initialize output
    sOutput = cell(1, length(sInputsA));

    % Fetch user options
    opt.intraCond           = sProcess.options.intraCond.Value;
    opt.log                 = sProcess.options.log.Value;
    opt.freq_type           = sProcess.options.freqtype.Value;
    opt.freq_range          = sProcess.options.freqrange.Value{1};
    opt.freq_bands          = sProcess.options.freqbands.Value;
    opt.p                   = sProcess.options.pvalue.Value{1};
    opt.normal              = sProcess.options.normal.Value;
    opt.test_normality      = sProcess.options.shapiro.Value;
    opt.report              = true; % Use report if in a Brainstorm process

    % Compute reference map
    [norm_values, sRefMapTemplate] = LoadNormData(sInputsB, opt);
    sRefMap = ComputeRefMap(norm_values, opt, sProcess, sRefMapTemplate);
    
    % For each subject in A, compare the PSD to the normative distribution
    for iSubA = 1:length(sInputsA)
        % Compute deviation map
        sDevMap = CompareToRefMap(sInputsA, iSubA, opt, sRefMap, []);

        % Reshape signif from nSources x nFreqs to nSources x 1 x nFreqs to
        % account for Brainstorm format
        s = size(sDevMap.signif);
        sDevMap.signif = reshape(sDevMap.signif, [s(1), 1, s(2)]);

        % Create the output file
        sOutput{iSubA} = SaveData(sDevMap.signif, opt, sDevMap.pData, sInputsA(iSubA), sInputsB, sProcess, opt.intraCond);
        db_reload_studies(sInputsA(iSubA).iStudy);
    end
end

function comment = GetComment(opt)
    % Initialize suffix for file comment
    comment_suffix = '';
    if opt.log
        comment_suffix = [comment_suffix, ' log'];
    end
    if opt.normal
        comment_suffix = [comment_suffix, ' normal'];
    end

    % Check that the options are valid and update the comment suffix
    if strcmp(opt.freq_type, 'indiv')
        % Check that the frequency range is valid
        if opt.freq_range(1) >= opt.freq_range(2)
            bst_report('error', 'Invalid frequency range');
            return
        end
        comment_suffix = [comment_suffix, sprintf(' %d-%dHz', opt.freq_range(1), opt.freq_range(2))];
    elseif strcmp(opt.freq_type, 'band')
        % Check that the frequency bands are valid
        if isempty(opt.freq_bands)
            bst_report('error', 'Invalid frequency bands');
            return
        end
        comment_suffix = [comment_suffix, ' bands'];
    end

    % Format the comment suffix
    if ~isempty(comment_suffix)
        comment_suffix = ['| ' comment_suffix];
    end
    comment = sprintf('comp. to norm: p < %.2f %s', opt.p, comment_suffix);
end

function pData = ProcessInput(data, opt)

    pData = data;

    % Retrieve type of input freqs (individual or band)
    if iscell(pData.Freqs)
        freqsType = 'band';
    else
        freqsType = 'indiv';
    end

    % If input in individual frequencies, exclude 0Hz
    if strcmp(freqsType, 'indiv') && (pData.Freqs(1) == 0) && (length(pData.Freqs) > 1)
        pData.Freqs = pData.Freqs(2:end);
        pData.TF = pData.TF(:, :, 2:end);
    end

    % If input is in bands, can only process by the same bands
    if strcmp(freqsType, 'band') && ~strcmp(opt.freq_type, 'input')
        bst_report('error', 'Input in frequency bands. Please select Process as: Same as input.');
        return
    end

    % Output as individual frequencies in a defined range
    if strcmp(opt.freq_type, 'indiv')
        fMask = (pData.Freqs - opt.freq_range(1) >= -1e-6) & (opt.freq_range(2) - pData.Freqs >= -1e-6);
        pData.Freqs = pData.Freqs(fMask);
        pData.TF = pData.TF(:, :, fMask);
        % Check that the frequency range is valid
        if isempty(pData.Freqs)
            bst_report('error', 'Input data out of the frequency range');
            return
        end

    % Output as frequency bands defined by the user
    elseif strcmp(opt.freq_type, 'band')
        % If data in individual frequencies, call function to generate bands
        [pData, messages] = process_tf_bands('Compute', pData, opt.freq_bands, []);
        % Error
        if isempty(pData)
            bst_report('error', messages);
            return;
        end
    end

    % If log values, apply log
    if opt.log
        pData.TF = log10(pData.TF);
    end
end

% Check that the frequencies and sources are the same across all subjects
function check = CheckInput(pData, sRefMap, fileName)
    try
        if abs(sum(pData.Freqs - sRefMap.refFreqs)) > 1e-6
            bst_report('error', 'All inputs must have the same frequencies. Check the input files. \nProblem with file: %s', fileName);
            return
        end
    catch
        if ~isequal(pData.Freqs, sRefMap.refFreqs)
            bst_report('error', 'All inputs must have the same frequencies. Check the input files. \nProblem with file: %s', fileName);
            return
        end
    end
    % Check that the number of sources is the same across all subjects
    if length(pData.RowNames) ~= sRefMap.nSources
        bst_report('error', 'All inputs must have the same number of sources. Check the input files. \nProblem with file: %s', fileName);
        return
    end
end

% Load normative values
function [norm_values, sRefMapTemplate] = LoadNormData(refInputs, opt)
    nNormativeSubjects = length(refInputs);

    for iSubB = 1:nNormativeSubjects

        % Get the data
        data = in_bst_timefreq(refInputs(iSubB).FileName);
        % Process the data (Freqs and TF) to match the options
        pData = ProcessInput(data, opt);
    
        % At first iteration, initialize the reference frequencies and the matrix to store the power values
        if iSubB == 1
            sRefMapTemplate.refFreqs = pData.Freqs;
            nFreqs = length(pData.Freqs);
            sRefMapTemplate.nSources = length(pData.RowNames);
            norm_values = zeros(sRefMapTemplate.nSources, nFreqs, nNormativeSubjects);
        else
            CheckInput(pData, sRefMapTemplate, refInputs(iSubB).FileName);
        end

        % Get the subject's PSD and store it in the norm_values matrix
        psd = pData.TF;
        norm_values(:, :, iSubB) = psd(:, 1, :);
    end
end

% Build normative distribution
function sRefMap = ComputeRefMap(norm_values, opt, sProcess, sRefMapTemplate)
    sRefMap = sRefMapTemplate;
    % Compute the mean and std of the normative distribution
    sRefMap.norm_means = mean(norm_values, 3);
    sRefMap.norm_stds = std(norm_values, 0, 3);

    % Compute the residuals (z-scores) for normative values
    residuals = (norm_values - sRefMap.norm_means) ./ sRefMap.norm_stds;

    if opt.normal && opt.test_normality
        % Assuming that the residuals are normally distributed
        % We can test the normality of the residuals using the Shapiro-Wilk test
        % Results are displayed in the report
        res_shapiro = zeros(sRefMap.nSources, nFreqs);
        p_shapiro = zeros(sRefMap.nSources, nFreqs);
        % Compute the Shapiro-Wilk test for normality
        for iSource = 1:sRefMap.nSources
            for iFreq = 1:nFreqs
                [h, p] = swtest(residuals(iSource, iFreq, :));
                res_shapiro(iSource, iFreq) = h;
                p_shapiro(iSource, iFreq) = p;
            end
        end

        if opt.report
            % Report the results
            bst_report('Info', sProcess, [], 'Shapiro-Wilk test for normality of residuals:');
            bst_report('Info', sProcess, [], sprintf('Significant at p < 0.05: %d/%d', sum(res_shapiro, "all"), sRefMap.nSources*nFreqs));
            bst_report('Info', sProcess, [], sprintf('Significant at p < 0.1: %d/%d', sum(p_shapiro < 0.1, "all"), sRefMap.nSources*nFreqs));
        else
            disp('Shapiro-Wilk test for normality of residuals:');
            fprintf('Significant at p < 0.05: %d/%d', sum(res_shapiro, "all"), sRefMap.nSources*nFreqs);
            fprintf('Significant at p < 0.1: %d/%d', sum(p_shapiro < 0.1, "all"), sRefMap.nSources*nFreqs);
        end
    end

    % Compute the percentiles of the distribution of residuals
    if opt.normal
        sRefMap.norm_percentile = norminv(1-opt.p/2);
    else
        sRefMap.percentiles = prctile(residuals, [(opt.p/2)*100, (1-(opt.p/2))*100], 3);
    end
end

% Compute the deviation map for one subject wrt sRefMap
% tf argument allows for preloading the data before, if data is not
% preloaded set tf to []
function sDevMap = CompareToRefMap(devInputs, iSub, opt, sRefMap, tf)

    % If data is not preloaded
    if isempty(tf)
        % Process the data
        data = in_bst_timefreq(devInputs(iSub).FileName);
        sDevMap.pData = ProcessInput(data, opt);
        CheckInput(sDevMap.pData, sRefMap, devInputs(iSub).FileName);
        tf = sDevMap.pData.TF;
    end

    % Compute the z-scores for the subject
    sDevMap.z_scores = (squeeze(tf(:,1,:)) - sRefMap.norm_means) ./ sRefMap.norm_stds;

    % Identify z_scores that are significantly different from the normative distribution
    if opt.normal
        sDevMap.signif = abs(sDevMap.z_scores) > sRefMap.norm_percentile;
    else
        sDevMap.signif = (sDevMap.z_scores < sRefMap.percentiles(:, :, 1)) | (sDevMap.z_scores > sRefMap.percentiles(:, :, 2));
    end
end

function output = SaveData(tf, opt, pData, input_file, refInputs, sProcess, intraCondName)
    % Assuming that Freqs is already processed in pData
    % Replace the TF data with the 0/1 matrix of significant values
    pData.TF = tf;
    % Add comment, change filename and save
    pData.ColormapType = 'stat2';

    % Get file comment from options
    comment = GetComment(opt);
    % file path suffix
    suffix = sprintf('comp_p_%.2d', opt.p*100);
    % Extract subject name from comment
    subName = strsplit(input_file.Comment, 'PSD');
    subName = subName{1};
    pData.Comment = [subName, ' ', comment];

    % History
    pData = bst_history('add', pData, 'comp2norm', comment);
    % History: List files used for normative
    pData = bst_history('add', pData, 'comp2norm', sprintf('File compared to normative: %s', input_file.FileName));
    pData = bst_history('add', pData, 'comp2norm', 'List of files used for normative distribution:');
    for i = 1:length(refInputs)
        pData = bst_history('add', pData, 'comp2norm', [' - ' refInputs(i).FileName]);
    end

    % Inputs for this file are the input file and the normative files
    sInputs = [input_file, refInputs];
    % Add new condition
    [sStudy, iStudy, ~, ~] = bst_process('GetOutputStudy', sProcess, sInputs, intraCondName, 1);
    [~, original_filename] = bst_fileparts(input_file.FileName);
    output = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), [original_filename, '_', suffix]);
    
    % Save the file
    bst_save(output, pData, 'v6');
    db_add_data(iStudy, output, pData);
end