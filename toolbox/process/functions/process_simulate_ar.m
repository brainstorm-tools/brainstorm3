function varargout = process_simulate_ar( varargin )
% PROCESS_SIMULATE_AR: Simulate source signals with an auto-regressive model
% Using this ARfit toolbox: https://climate-dynamics.org/software/#arfit
%
% USAGE:   OutputFiles = process_simulate_ar('Run', sProcess, sInputA)
%               signal = process_simulate_ar('Compute', b, A, C, nsamples)
%               sFiles = process_simulate_ar('Test')
 
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
% Authors: Guiomar Niso, 2013-2014
%          Raymundo Cassani, 2021-2022
%          Francois Tadel, 2013-2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Simulate AR signals (advanced)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Simulate'; 
    sProcess.Index       = 903; 
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
    sProcess.options.samples.Value   = {12000, ' (Ntime)', 0};
    % === SAMPLING FREQUENCY
    sProcess.options.srate.Comment = 'Signal sampling frequency:';
    sProcess.options.srate.Type    = 'value';
    sProcess.options.srate.Value   = {1200, 'Hz', 2};
    % === COEFFICIENT MATRIX
    sProcess.options.A.Comment = ['<BR>Using the ARSIM function from ARFIT Toolbox (T.Schneider):<BR>' ...
                                  '&nbsp;&nbsp;&nbsp;&nbsp;X = <B>b</B> + <B>A1</B>.X1 + ... + <B>Ap</B>.Xp + <B>noise</B><BR><BR>' ... 
                                  'Coefficient matrix <B>A</B> =  [A1 ... Ap]<BR>' ...
                                  '&nbsp;&nbsp;&nbsp;&nbsp; - p is the order of the autorregresive model<BR>' ...
                                  '&nbsp;&nbsp;&nbsp;&nbsp; - Ai: [Nsignals_to x Nsignals_from]<BR>'];
    sProcess.options.A.Type    = 'textarea';
    sProcess.options.A.Value   = ['A1 = [.8 0 .4 0; 0 .9 0 0; 0 .5 .5 0; 0 0 0 .2];', 10 ...
                                  'A2 = [-.5 .2 0 0; 0 -.8 0 0; 0 0 -.2 0; 0 0 0 -.4];', 10 ...
                                  'A = [A1, A2];'];
    % === INTERCEPT
    sProcess.options.b.Comment = 'Intercept <B>b</B>: &nbsp;&nbsp;[1 x Nsignals]';
    sProcess.options.b.Type    = 'textarea';
    sProcess.options.b.Value   = 'b = [.01 .08 -.02 .05];';
    % === NOISE COVARIANCE
    sProcess.options.C.Comment = 'Noise covariance matrix <B>C</B>: &nbsp;&nbsp;[Nsignals x Nsignals]<BR>';
    sProcess.options.C.Type    = 'textarea';
    sProcess.options.C.Value   = 'C = eye(4,4);';
    % === DISPLAY SPECTRAL METRICS
    sProcess.options.display.Comment = {'process_simulate_ar(''DisplayMetrics'');', '<BR>', 'View spectral metrics'};
    sProcess.options.display.Type    = 'button';
    sProcess.options.display.Value   = [];
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== GET COEFFICIENTS =====
function [A, b, C, errMsg] = GetCoefficients(sProcess)
    A = [];
    b = [];
    C = [];
    errMsg = '';
    % Evaluate Matlab code
    try
        eval(sProcess.options.A.Value);
        eval(sProcess.options.b.Value);
        eval(sProcess.options.C.Value);
    catch
        errMsg = lasterr();
        bst_report('Error', sProcess, [], errMsg);
        return;
    end    
    % Check variables dimensions
    if isempty(A) || isempty(b) || isempty(C)
        errMsg = 'One of the variables is not defined (A, b or C).';
        bst_report('Error', sProcess, [], errMsg);
        return;
    elseif (size(A,1) ~= size(b,2)) || (size(b,1) ~= 1) || (size(A,1) ~= size(C,1)) || (size(C,1) ~= size(C,2))
        errMsg = 'The dimensions of the input matrices are incompatible.';
        bst_report('Error', sProcess, [], errMsg);
        return;
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputA)
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
    srate   = sProcess.options.srate.Value{1};
    
    % Get coefficients
    [A, b, C, errMsg] = GetCoefficients(sProcess);
    if ~isempty(errMsg)
        bst_report('Error', sProcess, [], errMsg);
        return;
    end
    % Generate the signal
    try
        Data = Compute(b, A, C, nsamples);
    catch
        e = lasterr();
        bst_report('Error', sProcess, [], e);
        return;
    end
    
    % ===== GENERATE FILE STRUCTURE =====
    % Create empty matrix file structure
    FileMat = db_template('matrixmat');
    FileMat.Value       = Data;
    FileMat.Time        = (0:nsamples-1) ./ srate;
    FileMat.Comment     = sprintf('Simulated AR (%dx%d)', size(Data,1), nsamples);
    FileMat.Description = cell(size(Data,1),1);
    for i = 1:size(Data,1)
        FileMat.Description{i} = ['s', num2str(i)];
    end
    % Add history entry
    FileMat = bst_history('add', FileMat, 'process', 'Simulate AR signals:');
    FileMat = bst_history('add', FileMat, 'process', ['   ' strrep(sProcess.options.A.Value, char(10), ' ')]);
    FileMat = bst_history('add', FileMat, 'process', ['   ' strrep(sProcess.options.b.Value, char(10), ' ')]);
    FileMat = bst_history('add', FileMat, 'process', ['   ' strrep(sProcess.options.C.Value, char(10), ' ')]);
    
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
    % Output filename
    OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'matrix_simar');
    % Save file
    bst_save(OutputFiles{1}, FileMat, 'v6');
    % Register in database
    db_add_data(iStudy, OutputFiles{1}, FileMat);
end


%% ===== GENERATE SIGNALS =====
% Generate synthetic AR signals
% Authors: Guiomar Niso, 2013-2014
function yOut = Compute(b,A,C,samples)
    yOut = arsim(b',A,C,samples)';
end

function [v]=arsim(w,A,C,n,ndisc)
% ARSIM: Simulation of AR process, from ARFIT Toolbox
%
%  v=ARSIM(w,A,C,n) simulates n time steps of the AR(p) process
%
%     v(k,:)' = w' + A1*v(k-1,:)' +...+ Ap*v(k-p,:)' + eta(k,:)', 
%
%  where A=[A1 ... Ap] is the coefficient matrix, and w is a vector of
%  intercept terms that is included to allow for a nonzero mean of the
%  process. The vectors eta(k,:) are independent Gaussian noise
%  vectors with mean zero and covariance matrix C.
%
%  The p vectors of initial values for the simulation are taken to
%  be equal to the mean value of the process. (The process mean is
%  calculated from the parameters A and w.) To avoid spin-up effects,
%  the first 10^3 time steps are discarded. Alternatively,
%  ARSIM(w,A,C,n,ndisc) discards the first ndisc time steps.

%  Modified 13-Oct-00
%  Author: Tapio Schneider
%          tapio@gps.caltech.edu

    m = size(C,1);     % dimension of state vectors
    p = size(A,2)/m;   % order of process

    if (p ~= round(p))
        error('Bad arguments.');
    end

    if (length(w) ~= m | min(size(w)) ~= 1)
        error('Dimensions of arguments are mutually incompatible.')
    end
    w = w(:)';  % force w to be row vector

    % Check whether specified model is stable
    A1 = [A; eye((p-1)*m) zeros((p-1)*m,m)];
    lambda = eig(A1);
    if any(abs(lambda) > 1)
        error('The specified AR model is unstable.')
    end

    % Discard the first ndisc time steps; if ndisc is not given as input
    % argument, use default
    if (nargin < 5)
        ndisc = 10^3;
    end

    % Compute Cholesky factor of covariance matrix C
    [R, err]= chol(C);                    % R is upper triangular
    if err ~= 0
        error('Covariance matrix not positive definite.')
    end

    % Get ndisc+n independent Gaussian pseudo-random vectors with
    % covariance matrix C=R'*R
    randvec = randn([ndisc+n,m])*R;

    % Add intercept vector to random vectors
    randvec = randvec + ones(ndisc+n,1)*w;

    % Get transpose of system matrix A (use transpose in simulation because
    % we want to obtain the states as row vectors)
    AT      = A';

    % Take the p initial values of the simulation to equal the process mean,
    % which is calculated from the parameters A and w
    if any(w)
        %  Process has nonzero mean    mval = inv(B)*w'    where
        %             B = eye(m) - A1 -... - Ap;
        %  Assemble B
        B 	 = eye(m);
        for j=1:p
            B = B - A(:, (j-1)*m+1:j*m);
        end
        %  Get mean value of process
        mval = w / B';

        %  The optimal forecast of the next state given the p previous
        %  states is stored in the vector x. The vector x is initialized
        %  with the process mean.
        x    = ones(p,1)*mval;
    else
        %  Process has zero mean
        x    = zeros(p,m);
    end

    % Initialize state vectors
    u      = [x; zeros(ndisc+n,m)];

    % Simulate n+ndisc observations. In order to be able to make use of
    % Matlab's vectorization capabilities, the cases p=1 and p>1 must be
    % treated separately.
    if p==1
        for k=2:ndisc+n+1;
            x(1,:) = u(k-1,:)*AT;
            u(k,:) = x + randvec(k-1,:);
        end
    else
        for k=p+1:ndisc+n+p;
            for j=1:p;
                x(j,:) = u(k-j,:)*AT((j-1)*m+1:j*m,:);
            end
            u(k,:) = sum(x)+randvec(k-p,:);
        end
    end

    % return only the last n simulated state vectors
    v = u(ndisc+p+1:ndisc+n+p,:);
end


%% ===== COMPUTE SPECTRAL METRICS =====
function [Hf, Af, Sf, Cf, DTF, PC, PDC, w] = ComputeMetrics(At, Fs, n)
% Transfer function and other spectral metrics for MVAR process
%
% Input
%   At : Coefficients in time domain [To, From, Order]
%   Fs : Sampling frequency [Hz]
%   n  : Number of frequency points for transfer function  
%
% Output 
%   Hf  : Transfer function             [To, From, Freqs] REF[1]
%   Af  : Coefficients Freq domain      [To, From, Freqs] REF[1]
%   Sf  : Cross-power spectral density  [To, From, Freqs] REF[1] 
%   C   : Coherency (complex coherence) [To, From, Freqs] REF[1]
%   PC  : Partial coherence             [To, From, Freqs] REF[1,2] 
%   DTF : Directed transfer function    [To, From, Freqs] REF[1,3]
%   PDC : Partial directed coherence    [To, From, Freqs] REF[1,3]
%
% References
% [1] Baccalá, LA (2001), Partial directed coherence: A new concept in neural structure determination. 
%     https://doi.org/10.1007/PL00007990
% [2] Schlögl, A (2006), Analyzing event-related EEG data with multivariate autoregressive parameters.
%     https://doi.org/10.1016/S0079-6123(06)59009-0
% [3] Barrett, AB (2013), Directed spectral methods. 
%     https://doi.org/10.1007/978-1-4614-7320-6_414-2
 
    % Number of signals and order
    [n_signals, ~, n_order] = size(At);
    V         = eye(n_signals); 
    % Frequency range
    deltaF = Fs/2/n;
    w = linspace(deltaF, Fs/2, n);
    digw = 2*pi*w./Fs; 
    z    = exp(-1i*digw);
    % Allocate variables size [To, From, Freqs]
    zeros_array = zeros(n_signals, n_signals, length(w));
    complex_zeros_array = complex(zeros_array);
    Hf  = complex_zeros_array; % Transfer function             
    Af  = complex_zeros_array; % Coefficients Freq domain      
    Sf  = complex_zeros_array; % Cross-power spectral density  
    Cf   = complex_zeros_array;% Complex coherence             
    Gf  = complex_zeros_array; % Auxiliar to compute PC        
    PC  = complex_zeros_array; % Partial coherence             
    DTF = zeros_array;         % Directed transfer function    
    PDC = zeros_array;         % Partial directed coherence    

    % Transform coefficients to frequency domain
    % Af = I - sum_{1}^{order} At * z^k
    for iTo = 1 : n_signals
        for iFrom = 1 : n_signals
            Af_ij = 0;
            for iSample = 1 : n_order
                tmp = At(iTo, iFrom, iSample) * z.^iSample;
                Af_ij = Af_ij + tmp;
            end
            if iFrom == iTo
                Af(iTo,iFrom,:) = 1 - Af_ij;
            else
                Af(iTo,iFrom,:) = Af_ij;
            end
        end
    end

    % Compute Hf and Sf
    for f = 1:length(w)
        Hf(:,:,f) = pinv(Af(:,:,f));
        Sf(:,:,f) = Hf(:,:,f) * V * ctranspose(Hf(:,:,f));
        Sf(:,:,f) = Sf(:,:,f) / Fs;    % Scale cross-spectra to be [u^2/Hz]
        Gf(:,:,f) = pinv((Sf(:,:,f))); % = inv(Hf*V*ctransp(Hf)) = ctransp(Af)*inv(V)*Af
    end

    % Compute DTF, C, PC and PDC
    for f = 1:length(w)
        for i = 1:n_signals
            % DFT normalized
            DTF(i,:,f) = (abs(Hf(i,:,f)).^2)./sum(abs(Hf(i,:,f)).^2);
            for j = 1:n_signals
                Cf(i,j,f)  = Sf(i,j,f)/sqrt(Sf(i,i,f)*Sf(j,j,f));  
                PC(i,j,f)  = Gf(i,j,f)/sqrt(Gf(i,i,f)*Gf(j,j,f));
                PDC(i,j,f) = abs(Af(i,j,f))/sqrt(ctranspose(Af(:,j,f))*Af(:,j,f)); 
            end
        end
    end
end


%% ===== DISPLAY SPECTRAL METRICS =====
function DisplayMetrics() %#ok<DEFNU>
    % Get current process structure
    sProcess = panel_process_select('GetCurrentProcess');
    % Get options
    sfreq  = sProcess.options.srate.Value{1}; % Signal sampling frequency [Hz]
    % Get coefficients
    [A,~,~,errMsg] = GetCoefficients(sProcess);
    if ~isempty(errMsg)
        bst_error(['Error: Cannot compute coefficients.' 10 10 errMsg], 'Display metrics', 0);
        return;
    end
    A = reshape(A, size(A,1), size(A,1), [] );
    % Display spectral metrics
    hFig = HDisplayMetrics(A, sfreq); 
end


function hFig = HDisplayMetrics(A, sfreq)
    % Progress bar
    bst_progress('start', 'Spectral metrics', 'Updating graphs...');

    % Compute transfer function and other spectral metrics
    [Hf, ~, Sf, Cf, DTF, ~, PDC, Freqs] = ComputeMetrics(A, sfreq, 2^8); 
    n_signals = size(Hf, 1);
    metrics(1).title   = ' Transfer function ';
    metrics(1).value   = abs(Hf);
    metrics(1).dir     = 1;
    metrics(1).ylimits = [];
    metrics(1).ylabel  = '|H|';
    
    metrics(2).title   = ' Cross-spectral power density ';
    metrics(2).value   = abs(Sf);
    metrics(2).dir     = 0;
    metrics(2).ylimits = [];
    metrics(2).ylabel  = 'Power (signal units^2/Hz) ';
    
    metrics(3).title   = ' Magnitude squared coherence ';
    metrics(3).value   = abs(Cf).^2;
    metrics(3).dir     = 0;
    metrics(3).ylimits = [0, 1];
    metrics(3).ylabel  = 'MSC';
    
    metrics(4).title   = ' Directed transfer function ';
    metrics(4).value   = DTF;         % Already normalized
    metrics(4).dir     = 1;
    metrics(4).ylimits = [0, 1];
    metrics(4).ylabel  = '|DTF|^2';
    
    metrics(5).title   = ' Partial directed coherence';
    metrics(5).value   = abs(PDC).^2; % Normalized PDC
    metrics(5).dir     = 1;
    metrics(5).ylimits = [0, 1];
    metrics(5).ylabel  = '|PDC|^2';
       
    % Get existing specification figure
    hFig = findobj(0, 'Type', 'Figure', 'Tag', 'SpectralMetrics');
    % If the figure doesn't exist yet: create it
    if isempty(hFig)
        % Create figure
        hFig = figure(...
            'MenuBar',     'none', ...
            'Toolbar',     'figure', ...
            'NumberTitle', 'off', ...
            'Name',        'Spectral metrics', ...
            'Tag',         'SpectralMetrics', ...
            'Units',       'Pixels');
        % Resize figure to use all the figure area
        decorationSize = gui_layout('GetDecorationSize');
        [~, figArea] = gui_layout('GetScreenBrainstormAreas');
        gui_layout('PositionFigure', hFig, figArea, decorationSize);
    % Figure already exists: re-use it
    else
        clf(hFig);
        figure(hFig);
    end

    % Tab group, one tab per metric
    tabgp = uitabgroup(hFig);
    for iMetric = 1 : length(metrics)
        metric = metrics(iMetric);
        hTabTmp = uitab(tabgp,'Title', metric.title);           
        % Plot spectral metric
        yMaxLimit = 0;
        for iFrom = 1 : n_signals
            for iTo = 1 : n_signals
                tmpAxes = axes('Units', 'normalized', 'Parent', hTabTmp);
                subplot(n_signals, n_signals, ((iFrom-1)*n_signals) + iTo, tmpAxes);
                area(Freqs, squeeze(metric.value(iTo, iFrom, :)));
                tmpYLimits = get(tmpAxes, 'YLim');
                yMaxLimit = max(yMaxLimit, tmpYLimits(2));
                % Title showing directionality
                dirChar = ' , ';
                if metric.dir == 1
                    dirChar = ' \rightarrow ';
                end
                title(['Signal ', num2str(iFrom), dirChar, 'Signal ', num2str(iTo)])
                hAxesMetric(iFrom, iTo) = tmpAxes;
            end
        end
    
        % Frequency axes
        linkaxes(hAxesMetric,'x');
        set(hAxesMetric(1), 'XLim', [0, max(Freqs)]);
        for iAxes = 1:size(hAxesMetric,2)
            xlabel(hAxesMetric(end, iAxes), 'Frequency (Hz)');
        end
        % Metric y axes
        linkaxes(hAxesMetric,'y');
        if ~isempty(metric.ylimits)
            set(hAxesMetric(1), 'YLim', metric.ylimits);
        else
            set(hAxesMetric(1), 'YLim', [0, yMaxLimit]);
        end
        for iAxes = 1:size(hAxesMetric,1)
            ylabel(hAxesMetric(iAxes,1), metric.ylabel);
        end
    end
        
    bst_progress('stop');
end


%% ===== TEST FUNCTION =====
function sFiles = Test() %#ok<DEFNU>
    % Model proposed by Ding, Chen & Bressler (2006)
    % "Granger Causality: Basic Theory and Application to Neuroscience"
    % http://onlinelibrary.wiley.com/doi/10.1002/9783527609970.ch17/pdf
    %
    %    X(t) = 0.8*X(t-1) - 0.5*X(t-2) + 0.2*Y(t-2) + 0.4*Z(t-1) + eps(t)
    %    Y(t) = 0.9*Y(t-1) + 0.8*Y(t-2) + eps(t)
    %    Z(t) = 0.5*Y(t-1) + 0.5*Z(t-1) -0.2*Z(t-2) + eps(t)
    %    Interactions: 2>1  2>3  3>1
    
    sFiles = bst_process('CallProcess', 'process_simulate_ar', [], [], ...
        'subjectname', 'Test', ...
        'condition',   'Simulation', ...
        'samples',     12000, ...
        'srate',       1200, ...
        'A', ['A1 = [.8 0 .4 0; 0 .9 0 0; 0 .5 .5 0; 0 0 0 .2];' 10 'A2 = [-.5 .2 0 0; 0 -.8 0 0; 0 0 -.2 0; 0 0 0 -.4];' 10 'A = [A1, A2];'], ...
        'b', 'b = [.01 .08 -.02 .05];', ...
        'C', 'C = eye(4,4);');
end



