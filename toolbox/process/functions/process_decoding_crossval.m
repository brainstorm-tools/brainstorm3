function varargout = process_decoding_crossval( varargin )
% PROCESS_DECODING_CROSSVAL SVM decoding: Cross-validated decoding of two conditions.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Seyed-Mahdi Khaligh-Razavi, Dimitrios Pantazis, 2015

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Classification with cross-validation';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Decoding';
    sProcess.Index       = 701;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Decoding';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'matrix'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 2;
    sProcess.isPaired    = 1;

    % Definition of the options
    sProcess.options.description.Comment = ['Apply binary SVM/LDA classifier on MEG trials.<BR>' ...
                                            'Doing k-fold cross validation at each time point.<BR><BR>'];
    sProcess.options.description.Type    = 'label';
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG';
    % === lowpass filtering
    sProcess.options.lowpass.Comment = 'Low-pass cutoff frequency (0=disabled): ';
    sProcess.options.lowpass.Type    = 'value';
    sProcess.options.lowpass.Value   = {30,'Hz',2};
    % === the classifier : SVM or LDA
    sProcess.options.label1.Comment     = '<BR>Classifier:';
    sProcess.options.label1.Type        = 'label';
    sProcess.options.classifier.Comment = {'<B>Matlab SVM</B>: <FONT color="#777777">Requires the Statistics toolbox (Matlab)</FONT>', ...
                                           '<B>LibSVM</B>: <FONT color="#777777">Requires the LibSVM Toolbox (free)</FONT>', ...
                                           '<B>Matlab LDA</B>: <FONT color="#777777">Requires the Statistics toolbox (Matlab)</FONT>'};
    sProcess.options.classifier.Type    = 'radio';
    sProcess.options.classifier.Value   = 1;
    % === number of cross validation folds
    sProcess.options.kfold.Comment = 'Number of folds: ';
    sProcess.options.kfold.Type    = 'value';
    sProcess.options.kfold.Value   = {10,'',0};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputsA, sInputsB) %#ok<DEFNU>
    % Initialize returned variables
    OutputFiles = {};

    % Get options
    SensorTypes  = sProcess.options.sensortypes.Value;
    LowPass      = sProcess.options.lowpass.Value{1};
    kfold        = sProcess.options.kfold.Value{1};
    switch (sProcess.options.classifier.Value)
        case 1,  MethodClassif = 'MatlabSVM';
        case 2,  MethodClassif = 'LibSVM';
        case 3,  MethodClassif = 'MatlabLDA';
    end

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
    % Force the same number of trials in both conditions
    if (length(sInputsA) ~= length(sInputsB))
        bst_report('Error', sProcess, sInputsA, 'The number of trials must be the same in the two sets of files.');
        return;
    end
    % Check for the Signal Processing toolbox
    if ~bst_get('UseSigProcToolbox')
        bst_report('Error', sProcess, [], 'This process requires the Signal Processing Toolbox.');
        return;
    end
    % Check for the Statistics toolbox
    if ismember(MethodClassif, {'MatlabSVM', 'MatlabLDA'}) && ~exist('cvpartition')
        bst_report('Error', sProcess, [], 'This process requires the Statistics and Machine Learning Toolbox.');
        return;
        % Check for the LibSVM toolbox
    elseif strcmpi(MethodClassif, 'LibSVM') && ~exist('svmpredict')
        bst_report('Error', sProcess, [], ['This process requires the LibSVM Toolbox:' 10 'http://www.csie.ntu.edu.tw/~cjlin/libsvm/#download']);
        return;
    end

    % ============
    % Load trials
    [trial,Time] = load_trials_bs(sInputsA, sInputsB, LowPass, SensorTypes);
    % Run classifier analysis
    [Accuracy,Time] = classifier_contrast_conditions_CrossVal_bs(trial, Time, kfold, MethodClassif);

    % ===== CREATE OUTPUT FILE =====
    % Get comment for files A and B
    [tmp__, tmp__, CommentA] = bst_process('GetOutputStudy', sProcess, sInputsA, [], 0);
    [tmp__, tmp__, CommentB] = bst_process('GetOutputStudy', sProcess, sInputsB, [], 0);
    % Create file structure
    FileMat = db_template('matrixmat');
    FileMat.Comment     = [MethodClassif ' CV: ' CommentA ' vs. ' CommentB];
    FileMat.Value       = Accuracy;
    FileMat.Description = {'Accuracy'};  % Document the rows and/or the columns of the field "Value"
    FileMat.Time        = Time;

    % ===== OUTPUT CONDITION =====
    % Default condition name
    SubjectName = sInputsA(1).SubjectName;
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
    OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), ['matrix_decoding_cv_' lower(MethodClassif)]);
    % Save file
    bst_save(OutputFiles{1}, FileMat, 'v6');
    % Register in database
    db_add_data(iStudy, OutputFiles{1}, FileMat);
end


%% ===== LOADING DATA =====
% INPUTS:
%    - conditionA/B : sInputsA, sInputsB (the function forces equal number of trials in each group)
%    - SensorTypes  : List of channel types or names separated with commas
%    - LowPass      : Low pass frequency for data filtering
% Authors: Dimitrios Pantazis, Seyed-Mahdi Khaligh-Razavi
function [trial,Time] = load_trials_bs(sInputsA, sInputsB, LowPass, SensorTypes)
    % Load channel file
    ChannelMat = in_bst_channel(sInputsA(1).ChannelFile);
    % Find channel indices
    iChannels = channel_find(ChannelMat.Channel, SensorTypes);
    % Make sure channels are unique and sorted
    iChannels = unique(iChannels);

    % Low-pass filtering
    if (LowPass ~= 0)
        % Design low pass filter
        tempA = in_bst_data(sInputsA(1).FileName);
        order = max(100,round(size(tempA.F(iChannels,:),2)/10)); %keep one 10th of the timepoints as model order
        Fs    = 1 ./ (tempA.Time(2) - tempA.Time(1));
        h     = filter_design('lowpass', LowPass, order, Fs, 0);
    end

    % Load data
    bst_progress('start', 'Decoding', 'Loading data...', 1, length(sInputsA));
    for f = 1:length(sInputsA)
        bst_progress('inc',1);
        % disp(['Loading file ' num2str(f) ' of ' num2str(length(filesA))]);
        tempA = in_bst_data(sInputsA(f).FileName);
        tempB = in_bst_data(sInputsB(f).FileName);

        if LowPass ~= 0 % do low-pass filtering
            trial{1}{f} = filter_apply(tempA.F(iChannels,:),h); %smooth over time
            trial{2}{f} = filter_apply(tempB.F(iChannels,:),h); %smooth over time
        else % do not do the filtering
            trial{1}{f} = tempA.F(iChannels,:);
            trial{2}{f} = tempB.F(iChannels,:);
        end
    end
    bst_progress('stop');
    Time = tempA.Time;
end


%% ===== SVM DECODING =====
% Apply SVM classificaiton on MEG trials. Uses Stratified cross-validation.
% Authors: Seyed-Mahdi Khaligh-Razavi, Dimitrios Pantazis
function [accuracy,Time] = classifier_contrast_conditions_CrossVal_bs(trial, Time, kfold, MethodClassif)
    % Initialize
    ntimes = size(trial{1}{1},2);
    ntrials = min([length(trial{1}) length(trial{2})]);

    %correct for baseline std
    tndx = Time<0;
    for i = 1:2 %for both groups
        for j = 1:ntrials
            trial{i}{j} = trial{i}{j} ./ repmat( std(trial{i}{j}(:,tndx)')',1,ntimes );
        end
    end

    % == perform decoding ==
    %create the train/test set
    [ChannelLen, timeLen] = size(trial{1}{1});
    trialsA = zeros(length(trial{1}),ChannelLen, timeLen);
    trialsB = zeros(length(trial{1}),ChannelLen, timeLen);
    for i =1:length(trial{1})
        trialsA(i,:,:) = trial{1}{i};
        trialsB(i,:,:) = trial{2}{i};
    end
    all_trials = [trialsA;trialsB];
    labels = [ones(1,ntrials) 2*ones(1,ntrials)];
    crossValidatedAccuracy = zeros(1,ntimes);

    bst_progress('start','decoding','Cross validating ...',1,ntimes);

    for tndx = 1:ntimes
        bst_progress('inc', 1);
        switch (MethodClassif)
            case 'MatlabSVM'
                % train/test the svm classifier
                cp = cvpartition(labels,'k',kfold); % Stratified cross-validation
                trainedSVM = fitcsvm(squeeze(all_trials(:,:,tndx)),labels);
                svmCrosVal = crossval(trainedSVM,'cvPartition',cp);
                crossValidatedAccuracy(tndx) = 100 * (1 - svmCrosVal.kfoldLoss);
                
            case 'LibSVM'
                svmCrosValAcc = do_binary_cross_validation(labels',squeeze(all_trials(:,:,tndx)),'-s 0 -t 0 -q', 5);
                crossValidatedAccuracy(tndx) = 100 *svmCrosValAcc;
                
            case 'MatlabLDA'
                % === linear discriminant classification ===
                cp = cvpartition(labels,'k',kfold); % Stratified cross-validation
                trainedLDA = fitcdiscr(squeeze(all_trials(:,:,tndx)),labels);
                LDACrosVal = crossval(trainedLDA,'cvPartition',cp);
                crossValidatedAccuracy(tndx) = 100 * (1 - LDACrosVal.kfoldLoss);
        end
    end
    bst_progress('stop');
    % Return accuracy
    accuracy = crossValidatedAccuracy;
end



%% ===== filter_apply =====
% function Xf = filter_apply(X,h_filter);
%
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


%% ===== k-fold cross validation for LibSVM =====
% this is a modified version of
% one of the libSVM functions for cross-validation
function crossValAcc=do_binary_cross_validation(y, x, param, nr_fold)
    len = length(y);
    rand_ind = randperm(len);
    dec_values = [];
    labels = [];

    for i = 1:nr_fold % Cross training : folding
        test_ind = rand_ind((floor((i-1)*len/nr_fold)+1:floor(i*len/nr_fold))');
        train_ind = (1:len)';
        train_ind(test_ind) = [];
        model = svmtrain(y(train_ind),x(train_ind,:),param);
        [pred, acc, dec] = svmpredict(y(test_ind),x(test_ind,:),model, '-q');
        if model.Label(1) < 0;
            dec = dec * -1;
        end
        dec_values = vertcat(dec_values, dec);
        labels = vertcat(labels, y(test_ind));
    end

    bin_dec_values = (dec_values >= 0) - (dec_values < 0);
    crossValAcc = sum( labels==bin_dec_values)/length(labels);
end


