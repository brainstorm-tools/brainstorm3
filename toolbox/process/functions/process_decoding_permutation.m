function varargout = process_decoding_permutation( varargin )
% PROCESS_DECODING_PERMUTATION SVM/LDA decoding permutation: decoding of two conditions.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
    sProcess.Comment     = 'Classification with permutation';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Decoding';
    sProcess.Index       = 702;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Decoding';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'matrix'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 2;
    sProcess.isPaired    = 1;

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
    % === the classifier : SVM or LDA
    sProcess.options.label1.Comment     = '<BR>Classifier:';
    sProcess.options.label1.Type        = 'label';
    sProcess.options.classifier.Comment = {'<B>Matlab SVM</B>: <FONT color="#777777">Requires the Statistics toolbox (Matlab)</FONT>', ...
                                           '<B>LibSVM</B>: <FONT color="#777777">Requires the LibSVM Toolbox (free)</FONT>', ...
                                           '<B>Matlab LDA</B>: <FONT color="#777777">Requires the Statistics toolbox (Matlab)</FONT>'};
    sProcess.options.classifier.Type    = 'radio';
    sProcess.options.classifier.Value   = 1;
    % === number of permutations
    sProcess.options.num_permutations.Comment = 'Number of permutations: ';
    sProcess.options.num_permutations.Type    = 'value';
    sProcess.options.num_permutations.Value   = {100,'',0};
    % === trial bin size for sub-averaging
    sProcess.options.binSize.Comment = 'Trial bin size: ';
    sProcess.options.binSize.Type    = 'value';
    sProcess.options.binSize.Value   = {5,'',0};
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
    num_permutations   = sProcess.options.num_permutations.Value{1};
    binSize = sProcess.options.binSize.Value{1};
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
    [trial,Time] = process_decoding_crossval('load_trials_bs', sInputsA, sInputsB, LowPass, SensorTypes);
    %Run SVM permutation analysis
    [Accuracy,Time] = contrast_conditions_perm_bs(trial,Time,num_permutations,binSize,MethodClassif);

    % ===== CREATE OUTPUT FILE =====
    % Get comment for files A and B
    [tmp__, tmp__, CommentA] = bst_process('GetOutputStudy', sProcess, sInputsA, [], 0);
    [tmp__, tmp__, CommentB] = bst_process('GetOutputStudy', sProcess, sInputsB, [], 0);
    % Create file structure
    FileMat = db_template('matrixmat');
    FileMat.Comment     = [MethodClassif ' perm: ' CommentA ' vs. ' CommentB];
    FileMat.Value       = mean(Accuracy);
    FileMat.Std         = std(Accuracy);
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
    OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), ['matrix_decoding_perm_' lower(MethodClassif)]);
    % Save file
    bst_save(OutputFiles{1}, FileMat, 'v6');
    % Register in database
    db_add_data(iStudy, OutputFiles{1}, FileMat);
end




%% ===== PERMUTATION DECODING =====
% Apply SVM/LDA classificaiton on MEG trials. Uses trial subaverages and permutations
% Authors: Seyed-Mahdi Khaligh-Razavi, Dimitrios Pantazis
function [Accuracy,Time] = contrast_conditions_perm_bs(trial, Time, num_permutations, trial_bin_size, MethodClassif)
    % Initialize
    ntimes = size(trial{1}{1},2);
    ntrials = min([length(trial{1}) length(trial{2})]);
    nchannels = size(trial{1}{1},1);

    % Correct for baseline std
    tndx = Time<0;
    for i = 1:2 %for both groups
        for j = 1:ntrials
            baseStd = std(trial{i}{j}(:,tndx)')';
            baseStd(baseStd == 0) = 1; % Avoid division by zero
            trial{i}{j} = trial{i}{j} ./ repmat(baseStd, 1, ntimes);
        end
    end

    % Get labels for train and test groups
    nsamples = floor(ntrials/trial_bin_size);
    samples = reshape([1:nsamples*trial_bin_size],trial_bin_size,nsamples)';
    train_label = [ones(1,nsamples-1) 2*ones(1,nsamples-1)];
    test_label = [1 2];

    % === Perform decoding ===
    Accuracy = zeros(num_permutations,ntimes);
    % init progress bar
    bst_progress('start','permutation-based decoding','Permuting ...',1,num_permutations*ntimes);

    for p = 1:num_permutations
        % Randomize samples
        perm_ndx = randperm(nsamples*trial_bin_size);
        perm_samples = perm_ndx(samples);
        
        % Create samples
        train_trialsA = average_structure2(trial{1}(perm_samples(1:nsamples-1,:)));
        train_trialsB = average_structure2(trial{2}(perm_samples(1:nsamples-1,:)));
        train_trials = [train_trialsA;train_trialsB];

        test_trialsA = average_structure(trial{1}(perm_samples(end,:)));
        test_trialsB = average_structure(trial{2}(perm_samples(end,:)));
        test_trials = reshape([test_trialsA test_trialsB],[nchannels,ntimes,2]);
        test_trials = permute(test_trials,[3 1 2]);

        for tndx = 1:ntimes
            bst_progress('inc', 1);
            switch (MethodClassif)
                case 'MatlabSVM'
                    % =It is good practice to standardize the predictors
                    % If you set 'Standardize',true, then the software centers and scales each
                    %column of the predictor data (X) by the column mean and standard deviation, respectively.
                    trainedClassifier = fitcsvm(squeeze(train_trials(:,:,tndx)),train_label,'Standardize',true);
                    predictedLabels = predict(trainedClassifier,test_trials(:,:,tndx));
                    Accuracy(p,tndx)= 100*sum(predictedLabels'==test_label)/length(test_label);

                case 'LibSVM'
                    %lib-SVM
                    model = svmtrain(train_label',train_trials(:,:,tndx),'-s 0 -t 0 -q');
                    [predicted_label, accuracy, decision_values] = svmpredict(test_label', test_trials(:,:,tndx), model,'-q');
                    Accuracy(p,tndx) = accuracy(1);

            	case 'MatlabLDA'
                    % == LDA decoding
                    trainedClassifier = fitcdiscr(squeeze(train_trials(:,:,tndx)),train_label);
                    predictedLabels = predict(trainedClassifier,test_trials(:,:,tndx));
                    Accuracy(p,tndx)= 100*sum(predictedLabels'==test_label)/length(test_label);
            end
        end
    end
    bst_progress('stop');
end


%% ===== AVERAGE STRUCTURES =====
% Average structured arrays
% Author: Dimitrios Pantazis
function Ave = average_structure2(Struct)
    Ave = zeros([size(Struct,1) size(Struct{1})]);
    for i = 1:size(Struct,1)
        for j = 1:size(Struct,2)
            Ave(i,:,:) = squeeze(Ave(i,:,:)) + Struct{i,j};
        end
    end
    Ave = Ave/size(Struct,2);    
end  

function Ave = average_structure(Struct)
    Ave = zeros(size(Struct{1}));
    for i = 1:length(Struct)
        Ave = Ave + Struct{i};
    end
    Ave = Ave/length(Struct);    
end


