function varargout = process_decoding_svm( varargin )
% PROCESS_DECODING_SVM: Decoding of multiple conditions using SVM.

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
% Authors: Martin Cousineau, 2019; Dimitrios Pantazis, 2019

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'SVM decoding';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Decoding';
    sProcess.Index       = 702;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Decoding';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;

    % Definition of the options
    sProcess.options.description.Comment = ['Apply binary SVM/LDA classifier on MEG trials.<BR>' ...
                                            'Uses trial subaverages and permutations. <BR><BR>'];
    sProcess.options.description.Type    = 'label';
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG';
    % === lowpass filtering
    sProcess.options.lowpass.Comment = 'Low-pass cutoff frequency (0=disabled): ';
    sProcess.options.lowpass.Type    = 'value';
    sProcess.options.lowpass.Value   = {30,'Hz',2};
    % === number of permutations
    sProcess.options.num_permutations.Comment = 'Number of permutations: ';
    sProcess.options.num_permutations.Type    = 'value';
    sProcess.options.num_permutations.Value   = {50,'',0};
    % === trial bin size for sub-averaging
    sProcess.options.kfold.Comment = 'Number of folds: ';
    sProcess.options.kfold.Type    = 'value';
    sProcess.options.kfold.Value   = {5,'',0};
    % === decoding method
    sProcess.options.method.Comment = {'Pairwise', 'Temporal generalization', 'Multiclass', 'Decoding method:'};
    sProcess.options.method.Type    = 'radio_line';
    sProcess.options.method.Value   = 1;
    % === decoding model
    sProcess.options.model.Comment = 'Decoding model: ';
    sProcess.options.model.Type    = 'text';
    sProcess.options.model.Value   = 'svm';
    sProcess.options.model.Hidden  = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Initialize returned variables
    OutputFiles = {};
    % Check the number of files in input
    if length(sInputs) < 2
        bst_report('Error', sProcess, sInputs, 'Not enough files in input.');
        return;
    end
    
    % Get options
    SensorTypes     = sProcess.options.sensortypes.Value;
    LowPass         = sProcess.options.lowpass.Value{1};
    numPermutations = sProcess.options.num_permutations.Value{1};
    kFold           = sProcess.options.kfold.Value{1};
    model           = sProcess.options.model.Value;
    methods         = {'pairwise', 'temporalgen', 'multiclass'};
    method          = methods{sProcess.options.method.Value};
    
    % Ensure we are including the LibSVM folder in the Matlab path
    if strcmpi(model, 'svm')
        [isInstalled, errMsg] = bst_plugin('Install', 'libsvm');
        if ~isInstalled
            bst_report('Error', sProcess, [], errMsg);
            return;
        end
        bst_plugin('SetProgressLogo', 'libsvm');
    end
    % Check for the Signal Processing toolbox
    if LowPass > 0 && ~bst_get('UseSigProcToolbox')
        bst_report('Error', sProcess, sInputs, 'The Signal Processing Toolbox is required to apply a filter.');
        return;
    end
    
    % Create signal pairs
    allConditions = {sInputs.Condition};
    [uniqueConditions, tmp, conditionMapping] = unique(allConditions);
    numConditions = length(uniqueConditions);
    % Try to find trial group instead
    if numConditions == 1
        allConditions = cellfun(@str_remove_parenth, {sInputs.Comment}, 'UniformOutput', 0);
        [uniqueConditions, tmp, conditionMapping] = unique(allConditions);
        numConditions = length(uniqueConditions);
    end
    if numConditions == 1
        bst_report('Error', sProcess, [], 'Could not find more than one condition to decode.');
        return;
    end
    if strcmpi(method, 'pairwise')
        methodName = 'Pairwise';
        Description = cell(numConditions * (numConditions - 1) / 2, 1);
        iDesc = 1;
        for iCond1 = 1:numConditions
            for iCond2 = iCond1+1:numConditions
                Description{iDesc} = [uniqueConditions{iCond2} ' vs ' uniqueConditions{iCond1}];
                iDesc = iDesc + 1;
            end
        end
    elseif strcmpi(method, 'temporalgen')
        methodName = 'Temporal generalization';
        Description = 'Average accuracy';
    else
        bst_report('Error', sProcess, [], ['Decoding using the ' method ' method is not yet supported.']);
        return;
    end
    
    % Summarize trials and conditions to process
    fprintf('BST> Found %d different conditions across %d trials:%c', numConditions, length(sInputs), char(10));
    for iCondition = 1:numConditions
        numOccurences = sum(conditionMapping == iCondition);
        fprintf(' %d. Condition "%s" with %d associated trials%c', iCondition, uniqueConditions{iCondition}, numOccurences, char(10));
    end

    % Load trials
    [trial,Time] = load_trials_bs(sInputs, LowPass, SensorTypes);
    % Run SVM decoding
    if strcmpi(model, 'maxcorr')
        % Run max-correlation decoding
        modelName = 'max-correlation';
        bst_progress('start', 'Decoding', 'Decoding with max-correlation model...');
        d = sll_decodemaxcorr(trial, allConditions, 'method', method, 'numpermutation', numPermutations, 'verbose', 1, 'kfold', kFold);
    else
        % Check installation of libsvm
        if isempty(which('svmtrain'))
            bst_report('Error', sProcess, [], ['Could not find function: svmtrain.' mexext 10 'The library libsvm is not installed or not compiled yet.' 10 ...
                'See instructions in the online tutorial: ' 10 'https://neuroimage.usc.edu/brainstorm/Tutorials/Decoding#Download_and_installation']);
            return;
        end
        % Default: basic SVM model
        modelName = 'SVM';
        bst_progress('start', 'Decoding', 'Decoding with SVM model...');
        d = sll_decodesvm(trial, allConditions, 'method', method, 'numpermutation', numPermutations, 'verbose', 2, 'kfold', kFold);
    end
    
    % Extract output in appropriate way for chosen method
    if strcmpi(method, 'temporalgen')
        Value = mean(d.d,3);
    else
        Value = d.d';
    end
    
    % ===== CREATE OUTPUT FILE =====
    % Create file structure
    FileMat = db_template('matrixmat');
    FileMat.Comment     = sprintf('%s %s on %d classes', methodName, modelName, numConditions);
    FileMat.Value       = double(Value);
    FileMat.Description = Description;
    FileMat.Time        = Time;
    FileMat.CondLabels  = uniqueConditions;

    % ===== OUTPUT CONDITION =====
    % Default condition name
    SubjectName = sInputs(1).SubjectName;
    Condition = 'decoding';
    % Get condition asked by user
    [sStudy, iStudy] = bst_get('StudyWithCondition', bst_fullfile(SubjectName, Condition));
    % Condition does not exist: create it
    if isempty(sStudy)
        iStudy = db_add_condition(SubjectName, Condition, 1);
        sStudy = bst_get('Study', iStudy);
    end

    % ===== SAVE FILE =====
    % Output filename
    OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), ['matrix_decoding_' model '_' method]);
    % Save file
    bst_save(OutputFiles{1}, FileMat, 'v6');
    % Register in database
    db_add_data(iStudy, OutputFiles{1}, FileMat);
    % Remove logo
    bst_plugin('SetProgressLogo', []);
end


%% ===== LOADING DATA =====
% INPUTS:
%    - sInputs      : Trial files to load
%    - SensorTypes  : List of channel types or names separated with commas
%    - LowPass      : Low pass frequency for data filtering
% Authors: Dimitrios Pantazis, Seyed-Mahdi Khaligh-Razavi, Martin Cousineau
function [trial, Time] = load_trials_bs(sInputs, LowPass, SensorTypes)
    % Load channel file
    ChannelMat = in_bst_channel(sInputs(1).ChannelFile);
    % Parse inputs
    if nargin < 2 || isempty(LowPass)
        LowPass = 0;
    end
    if nargin < 3 || isempty(SensorTypes)
        % Select all channels
        iChannels = 1:length(ChannelMat.Channel);
    else
        % Find channel indices
        iChannels = channel_find(ChannelMat.Channel, SensorTypes);
        % Make sure channels are unique and sorted
        iChannels = unique(iChannels);
    end
    
    % Initialize output matrix (numChannels x numSamples x numObservations)
    nInputs = length(sInputs);
    DataMat  = in_bst_data(sInputs(1).FileName);
    trial = zeros(length(iChannels), length(DataMat.Time), nInputs);

    % Low-pass filtering
    if LowPass > 0
        % Design low pass filter
        order = max(100,round(size(DataMat.F(iChannels,:),2)/10)); %keep one 10th of the timepoints as model order
        Fs    = 1 ./ (DataMat.Time(2) - DataMat.Time(1));
        h     = filter_design('lowpass', LowPass, order, Fs, 0);
    end

    % Load data    
    bst_progress('start', 'Decoding', 'Loading data...', 1, nInputs);
    for f = 1:nInputs
        bst_progress('inc',1);
        DataMat = in_bst_data(sInputs(f).FileName);

        if LowPass > 0 % do low-pass filtering
            trial(:,:,f) = filter_apply(DataMat.F(iChannels,:),h); %smooth over time
        else % do not do the filtering
            trial(:,:,f) = DataMat.F(iChannels,:);
        end
    end
    bst_progress('stop');
    Time = DataMat.Time;
end


%% ===== filter_apply =====
% function Xf = filter_apply(X,h_filter);
%9
% Applies the FIR h_filter to the timeseries on the matrix X (ntimeseries x ntimes)
%
% INPUTS:
%   X: matrix of timeseries (nTimeseries x nTimes)
%   h_filter: filter coefficients
%
% OUTPUTS:
%   Xf: matrix of filtered timeseries
%
% Also see: FILTER_DESIGN
%
% Author: Dimitrios Pantazis, February 2009
function Xf = filter_apply(X,h_filter)
    %test inputs
    if nargin == 0 %if no input
        help filter_apply %display help
        return
    end
    %apply filter
    Xf = zeros(size(X));
    for i = 1:size(X,1)
        Xf(i,:) = filtfilt(h_filter,1,X(i,:));
    end
end


%% ===== filter_design =====
% function h_filter = filter_design(filter_type,param,order, Fs,show_plot)
%
% Easy interface to design a highpass or lowpass filter using firls
% The function firls Designs a linear-phase FIR filter that minimizes the weighted,
% integrated squared error between an ideal piecewise linear function and the magnitude
% response of the filter over a set of desired frequency bands.
%
% INPUTS:
%
%   filter_type: string containing the values 'highpass' or 'lowpass' or 'bandpass' or 'notch'
%
%   param: parameters of the filter
%       if 'highpass', params is a scalar denoting the cutoff frequency
%       if 'lowpass', params is a scalar denoting the cutoff frequency
%       if 'notch', params is a 2x1 vector [fnotch delta], and the notch filter cancels all frequencies between fnotch-delta and fnotch+delta
%       if 'bandpass', params is a 2x1 vector [fmin fmax], denoting the band pass
%       if 'bandstop', params is a 2x1 vector [fmin fmax], denoting the band stop
%
%   order: (default 50) order of the FIR filter. The higher the value, the more precise the filter response
%
%   Fs: sampling frequency of the signal to be filtered
%
%   show_plot: (0 or 1, optional) plots the filter response and some test signals
%
% OUTPUT:
%   Filter coefficients
%
% EXAMPLES:
%
%   order = 50;
%   Fs = 200; %sampling frequency at 200Hz
%   h = filter_design('lowpass',20,order,Fs,1); %low pass filter at 20Hz
%   h = filter_design('highpass',30,order,Fs,1); %high pass filter at 30Hz
%   h = filter_design('bandpass',[20 30],order,Fs,1); %band pass filter at 20-30Hz
%   h = filter_design('bandstop',[20 30],order,Fs,1); %band stop filter at 20-30Hz
%   h = filter_design('notch',[60 1.5],200,Fs,1); %notch filter at 60Hz (with pass at 58.5-61.5 Hz)
%
%
% Also see: FILTER_APPLY
%
% Author: Dimitrios Pantazis, February 2009
function h_filter = filter_design(filter_type,param,order,Fs,show_plot)
    % Test inputs
    if nargin == 0 %if no input
        help filter_design %display help
        return
    end
    if ~exist('show_plot', 'var')
        show_plot = 1;
    end
    if ~exist('order', 'var')
        order = 50;
    end

    switch filter_type
        case 'highpass'
            fhigh = param(1);
            fc = fhigh * 2/Fs;   %1 for Nyquist frequency (half the sampling rate)
            h_filter = firls(order, [0 fc fc 1], [0 0 1 1]).*kaiser(order+1,5)';

        case 'lowpass'
            flow = param(1);
            fc = flow * 2/Fs;   %1 for Nyquist frequency (half the sampling rate)
            h_filter = firls(order, [0 fc fc 1], [1 1 0 0]).*kaiser(order+1,5)';

        case 'notch'
            fnotch = param(1);
            delta = param(2);
            fc = fnotch * 2/Fs;   %1 for Nyquist frequency (half the sampling rate)
            d = delta * 2/Fs;
            h_filter = firls(order, [0 fc-d fc-d fc+d fc+d 1], [1 1 0 0 1 1]).*kaiser(order+1,5)';

        case 'bandpass'
            flow = param(1);
            fhigh = param(2);
            fc1 = flow * 2/Fs;
            fc2 = fhigh * 2/Fs;
            h_filter = firls(order, [0 fc1 fc1 fc2 fc2 1], [0 0 1 1 0 0]).*kaiser(order+1,5)';

        case 'bandstop'
            flow = param(1);
            fhigh = param(2);
            fc1 = flow * 2/Fs;
            fc2 = fhigh * 2/Fs;
            h_filter = firls(order, [0 fc1 fc1 fc2 fc2 1], [1 1 0 0 1 1]).*kaiser(order+1,5)';
    end

    % Create test sinusoids
    fcutoff = param(1);
    t_end = max((30*1/fcutoff)*Fs,order*3);   %data must have length more that 3 times filter order
    t = 0:1/Fs:t_end/Fs;
    xcut = sin(2*pi*fcutoff*t);
    x1 = sin(2*pi*(fcutoff*90/100)*t);
    x2 = sin(2*pi*(fcutoff*110/100)*t);
    xcutf = filtfilt(h_filter,1,xcut);
    x1f = filtfilt(h_filter,1,x1);
    x2f = filtfilt(h_filter,1,x2);

    % Display and test filter
    if show_plot
        [h,f] = freqz(h_filter,1,linspace(0,Fs/2,1000),Fs);
        figure;
        subplot(321);
        plot(f,abs(h));
        grid on
        xlabel('Frequency (Hz)');
        ylabel('Magnitude');
        title('Filter Response','fontsize',12)
        subplot(323)
        plot(f,20*log10(abs(h)));
        grid on
        xlabel('Frequency (Hz)');
        ylabel('Magnitude (dB)');
        subplot(325);
        plot(f,(180/pi*unwrap(angle(h))))
        grid on
        xlabel('Frequency (Hz)');
        ylabel('Phase (degrees)');
        subplot(322);
        plot(t,x1f);
        xlabel('Time (sec)');
        ylabel(['Sinusoid at ' num2str(fcutoff*90/100) ' Hz' ]);
        title('Filtered Sinusoids of Amplitude 1','fontsize',12)
        subplot(324);
        plot(t,xcutf);
        xlabel('Time (sec)');
        ylabel(['Sinusoid at ' num2str(fcutoff) ' Hz' ]);
        subplot(326);
        plot(t,x2f);
        xlabel('Time (sec)');
        ylabel(['Sinusoid at ' num2str(fcutoff*110/100) ' Hz' ]);
    end
end
