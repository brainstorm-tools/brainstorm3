function varargout = process_simulate_ar_random( varargin )
% PROCESS_SIMULATE_AR_RANDOM: Simulate source signals with an auto-regressive model
%
% USAGE:   OutputFiles = process_simulate_ar_random('Run', sProcess, sInputA)
%               signal = process_simulate_ar_random('Compute', b, A, C, nsamples)
%               sFiles = process_simulate_ar_random('Test')
 
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
% Authors: Syed Ashrafulla, Francois Tadel, 2014

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Simulate AR signals (random)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Simulate'; 
    sProcess.Index       = 904; 
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;

    % === SUBJECT NAME
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = 'Test';
    % === CONDITION NAME
    sProcess.options.condition.Comment = 'Condition name:';
    sProcess.options.condition.Type    = 'text';
    sProcess.options.condition.Value   = 'Simulation';
    % === NUMBER OF SAMPLES
    sProcess.options.samples.Comment = 'Number of time samples:';
    sProcess.options.samples.Type    = 'value';
    sProcess.options.samples.Value   = {10000, ' (Ntime)', 0};
    % === SAMPLING FREQUENCY
    sProcess.options.srate.Comment = 'Signal sampling frequency:';
    sProcess.options.srate.Type    = 'value';
    sProcess.options.srate.Value   = {1000, 'Hz', 2};
    % === SNR
    sProcess.options.snr.Comment = 'Signal to noise ratio (SNR):';
    sProcess.options.snr.Type    = 'value';
    sProcess.options.snr.Value   = {2, ' ', 2};
    % === ORDER
    sProcess.options.order.Comment = 'Order of the auto-regressive model:';
    sProcess.options.order.Type    = 'value';
    sProcess.options.order.Value   = {16, ' ', 0};
    % === NUMBER OF TRIALS
    sProcess.options.ntrials.Comment = 'Number of trials to generate:';
    sProcess.options.ntrials.Type    = 'value';
    sProcess.options.ntrials.Value   = {1, ' ', 0};
    % === TOPOGRAPHY MATRIX
    sProcess.options.T.Comment = 'Topography of causal network:   [to x from]';
    sProcess.options.T.Type    = 'textarea';
    sProcess.options.T.Value   = ['T = [' 10 ...
                                  '0 1 0 0 0 0; ' 10 ...
                                  '1 0 0 0 1 0; ' 10 ...
                                  '0 0 0 0 0 0; ' 10 ...
                                  '0 0 0 0 1 0; ' 10 ...
                                  '0 0 0 1 0 0; ' 10 ...
                                  '0 0 0 0 0 0];'];
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputA) %#ok<DEFNU>
    OutputFiles = {};
    % === GET OPTIONS ===
    % Get subject name
    SubjectName = file_standardize(sProcess.options.subjectname.Value);
    if isempty(SubjectName)
        bst_report('Error', sProcess, sInputs, 'Subject name is empty.');
        return
    end
    % Get condition name
    Condition = file_standardize(sProcess.options.condition.Value);
    % Get signal options
    nsamples = sProcess.options.samples.Value{1};
    srate    = sProcess.options.srate.Value{1};
    order    = sProcess.options.order.Value{1};
    snr      = sProcess.options.snr.Value{1};
    nTrials  = sProcess.options.ntrials.Value{1};
    
    % ===== GENERATE SIGNALS =====
    T = [];
    % Evaluate Matlab code
    try
        eval(sProcess.options.T.Value);
    catch
        e = lasterr();
        bst_report('Error', sProcess, [], e);
        return;
    end
    % Check variables dimensions
    if isempty(T)
        bst_report('Error', sProcess, [], 'Variable T is not defined.');
        return;
    end
    % Generate the signal
    try
        Data = Compute(T, order, srate, nsamples, nTrials, snr, true);
    catch
        e = lasterr();
        bst_report('Error', sProcess, [], e);
        return;
    end
    
    % ===== GENERATE FILE STRUCTURE =====
    % Create empty matrix file structure
    FileMat = db_template('matrixmat');
    FileMat.Time        = (0:nsamples-1) ./ srate;
    FileMat.Description = cell(size(Data,1),1);
    for i = 1:size(Data,1)
        FileMat.Description{i} = ['s', num2str(i)];
    end
    % Add history entry
    FileMat = bst_history('add', FileMat, 'process', 'Simulate AR (random) signals:');
    FileMat = bst_history('add', FileMat, 'process', ['   ' strrep(sProcess.options.T.Value, char(10), ' ')]);
    
    % === OUTPUT CONDITION ===
    % Get subject
    [sSubject, iSubject] = bst_get('Subject', SubjectName);
    % Create subject if it does not exist yet
    if isempty(sSubject)
        [sSubject, iSubject] = db_add_subject(SubjectName);
    end
    % Default condition name
    if isempty(Condition)
        Condition = 'Simulation';
    end
    % Get condition asked by user
    [sStudy, iStudy] = bst_get('StudyWithCondition', bst_fullfile(SubjectName, Condition));
    % Condition does not exist: create it
    if isempty(sStudy)
        iStudy = db_add_condition(SubjectName, Condition, 1);
        sStudy = bst_get('Study', iStudy);
    end
    
    % === SAVE FILE ===
    for iTrial = 1:nTrials
        % Data for this trial
        FileMat.Value   = Data(:,:,iTrial);
        if (nTrials > 1)
            FileMat.Comment = sprintf('Simulated AR random (%dx%d) #%d', size(Data,1), nsamples, iTrial);
        else
            FileMat.Comment = sprintf('Simulated AR random (%dx%d)', size(Data,1), nsamples);
        end
        % Output filename
        OutputFiles{iTrial} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'matrix_simarrand');
        % Save file
        bst_save(OutputFiles{iTrial}, FileMat, 'v6');
        % Register in database
        db_add_data(iStudy, OutputFiles{iTrial}, FileMat);
    end
end



%% ===== GENERATE SIGNALS =====
% Generate random AR signals
% Authors: Syed Ashrafulla, 2014
function [signals, sources, phases] = Compute(topography, order, Fs, nTimes, nTrials, SNR, zeromean, standardize)
    % Parse inputs
    if (nargin < 7) || isempty(zeromean)
        zeromean = 1;
    end  
    if (nargin < 8) || isempty(standardize)
        standardize = 0;
    end
    nSignals = size(topography, 1);

    % ===== Build transfer function (i.e. AR coefficients) =====
    % Put the poles in equally-spaced spots
    phases = linspace(0, Fs/2, order/2 + 2) / (Fs/2) * pi; phases = phases(2 : end-1);
    % Initialize with a very bad transfer function
    transfers = 2;
    % Loop until the transfer function is stable
    while bst_mvar_companion(transfers) > 0.99998
        % The magnitudes will be random for each signal
        magnitudes = rand(nSignals, length(phases)) * 0.2 + 0.75;
        % The extrema are symmetric
        if mod(order, 2) % if order is odd, we add a peak at pi that is pretty weak
            extrema = [bst_bsxfun(@times, magnitudes, exp(1i * phases)) bst_bsxfun(@times, magnitudes, exp(-1i * phases)) -(rand(nSignals, 1) * 0.1 + 0.4)];
        else
            extrema = [bst_bsxfun(@times, magnitudes, exp(1i * phases)) bst_bsxfun(@times, magnitudes, exp(-1i * phases))];
        end
        % Start the build of the transfer function by filling in the diagonal of each transfer matrix with the coefficients for the extrema calculated above
        transfers = zeros(nSignals, nSignals, order);
        for iSignal = 1:nSignals
            [syed, current] = zp2tf([], extrema(iSignal, :), 1); %#ok<ASGLU> % their AR model is x[n] + A x[n-1] = e[n]
            transfers(iSignal, iSignal, :) = -current(2:end); % to fit our version of the AR model (x[n] = A x[n-1] + e[n]) rather than theirs (x[n] + A x[n-1] = e[n])
        end
        % Use the topography to generate the off-diagonal coefficients
        for p = 1:order
            transfers(:, :, p) = transfers(:, :, p) + (transfers(:, :, p) * topography) .* (rand(nSignals) * 0.2 + 0.7);
        end
    end

    % ===== Set up autoregression =====
    % Minimum number of iterations
    burnin = 5000;
    nIterations = ceil((nTimes + order)*4/3) + burnin;
    % Pre-allocation: initialize signals to white noise
    sources = zeros(nSignals, nTrials, nIterations);
    innovations = randn(nSignals, nTrials, nIterations) / sqrt(Fs);
    sources(:, :, 1:order) = innovations(:, :, 1:order);
    
    % ===== Simulation by stepping through the autoregression =====
    % Iterate over each timepoint
    for n = (order+1):nIterations
        % New data (the last part of the AR equation)
        sources(:, :, n) = innovations(:, :, n);
        % Autoregression (the sum in the AR equation)
        for p = 1:order
            sources(:, :, n) = sources(:, :, n) + transfers(:, :, p) * sources(:, :, n-p);
        end
    end

    % ===== Noisy signals =====
    % We want signals to be S (number of signals) x N (number of times) x T (number of trials)
    sources = permute(sources(:, :, (end-nTimes+1):end), [1 3 2]);
    % innovations = permute(innovations(:, :, (end-nTimes+1):end), [1 3 2]);
    % White noise
    noise = randn(nSignals, nTimes, nTrials);
    % Power for each trial
    sourcePower = zeros(nSignals, 1, nTrials);
    noisePower = zeros(nSignals, 1, nTrials);
    for idxSignal = 1:nSignals
        for trial = 1:nTrials
            sourcePower(idxSignal, 1, trial) = sum(sources(idxSignal, :, trial).^2);
            noisePower(idxSignal, 1, trial) = sum(noise(idxSignal, :, trial).^2);
        end
    end
    % Set total power to 1 and then divide to get desired noise power for given SNR
    ratio = sqrt(sourcePower ./ noisePower) / sqrt(SNR);
    if any(ratio > 0)
        noise = noise .* repmat(ratio, [1 nTimes 1]);
    end
    signals = sources + noise;

    % ===== Standardize every trial =====
    if (zeromean)
        % Correct each trial
        for trial = 1:nTrials
            % Detrend and force unit variance in noisy signals
            signals(:,:,trial) = signals(:,:,trial) - mean(signals(:,:,trial), 2) * ones(1, nTimes);
            if (standardize)
                signals(:, :, trial) = diag(1./sqrt(sum(signals(:,:,trial).^2 / (nTimes-1), 2))) * signals(:,:,trial);
            end
            % Detrend and force unit variance in noiseless sources
            sources(:,:,trial) = sources(:,:,trial) - mean(sources(:,:,trial), 2) * ones(1, nTimes);
            if (standardize)
                sources(:, :, trial) = diag(1./sqrt(sum(sources(:,:,trial).^2 / (nTimes-1), 2))) * sources(:,:,trial);
            end
        end
    end
end


%% ===== MVAR COMPAGNION =====
function [lambda, A] = bst_mvar_companion(transfers)
    % BST_MVAR_COMPANION  Companion matrix of a VAR process
    %
    % Inputs:
    %   transfers       - Transfer matrices in AR process.
    %                     Flat (2D, size N x NP) or Expanded (3D, size N x N X P)
    %                     N = # of sources, P = order
    %
    % Outputs:
    %   lambda          - Maximum eigenvalue of companion matrix.
    %                     A set of transfer coefficients is stable if lambda < 1
    %   companion       - Companion matrix of transfer function. For the system
    %
    %                            x_k = \sum_{p=1}^P A_p x_{k-p} + \eta_p
    %
    %                     where A_p is represented in transfers, the companion is
    %                          _                                     _
    %                         |       ¦       ¦       ¦       ¦       |
    %                         |  A_1  ¦  A_2  ¦  A_3  ¦  ...  ¦  A_P  |
    %                         |_______¦_______¦_______¦_______¦_______|
    %                         |       ¦       ¦       ¦       ¦       |
    %                         |   I   ¦   0   ¦   0   ¦   0   ¦   0   |
    %                     C = |_______¦_______¦_______¦_______¦_______|
    %                         |       ¦       ¦       ¦       ¦       |
    %                         |   0   ¦   I   ¦   0   ¦   0   ¦   0   |
    %                         |_______¦_______¦_______¦_______¦_______|
    %                         |       ¦       ¦       ¦       ¦       |
    %                         |   :   ¦   :   ¦   :   ¦   :   ¦   :   |
    %                         |_______¦_______¦_______¦_______¦_______|
    %                         |       ¦       ¦       ¦       ¦       |
    %                         |   0   ¦   0   ¦   0   ¦   I   ¦   0   |
    %                         |_      ¦       ¦       ¦       ¦      _|
    %                     and lambda is its maximum eigenvalue.
    %
    % Call:
    %   (bst_mvar_companion(transfers) < 1) <-- test for stability
    %   lambda = bst_mvar_companion(transfers) <-- Get closest pole to instability
    %   [lambda, A] = bst_mvar_companion(transfers) <-- Get full companion

    % Setup
    nSources = size(transfers, 1);

    if ndims(transfers) == 3
      if exist('order', 'var')
        warning('BST_MVAR_COMPANION:order', 'Overwriting your order with the order of the 3D transfer matrix');
      end
      order = size(transfers, 3);
    elseif ndims(transfers) == 2 && mod(size(transfers,2), nSources) < eps
      order = round(size(transfers,2) / nSources);
    else % Flat transfer matrix sent with non-integer order
      error('BST_MVAR_COMPANION:order', 'Invalid transfer matrix: # of columns not divisible by # of rows');
    end

    transfersFlat = reshape(transfers, nSources, []);

    % Companion & stability eigenvalue
    A = [transfersFlat; eye(nSources*(order-1)) zeros(nSources*(order-1), nSources)];
    lambda = max(abs(eig(A)));
end




%% ===== TEST FUNCTION =====
function sFiles = Test() %#ok<DEFNU>   
    sFiles = bst_process('CallProcess', 'process_simulate_ar_random', [], [], ...
        'subjectname', 'Test', ...
        'condition',   'Simulation', ...
        'samples',     12000, ...
        'srate',       1200, ...
        'order',       16, ...
        'snr',         2, ...
        'T',     'T = [0 1 0 0 0 0; 1 0 0 0 1 0; 0 0 0 0 0 0; 0 0 0 0 1 0; 0 0 0 1 0 0; 0 0 0 0 0 0];');
end



