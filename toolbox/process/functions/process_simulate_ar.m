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
% Authors: Guiomar Niso, Francois Tadel, 2013-2014

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Simulate AR signals (ARfit)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Simulate'; 
    sProcess.Index       = 902; 
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
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
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
    srate   = sProcess.options.srate.Value{1};
    
    % ===== GENERATE SIGNALS =====
    A = [];
    b = [];
    C = [];
    % Evaluate Matlab code
    try
        eval(sProcess.options.A.Value);
        eval(sProcess.options.b.Value);
        eval(sProcess.options.C.Value);
    catch
        e = lasterr();
        bst_report('Error', sProcess, [], e);
        return;
    end
    % Check variables dimensions
    if isempty(A) || isempty(b) || isempty(C)
        bst_report('Error', sProcess, [], 'One of the variables is not defined (A, b or C).');
        return;
    elseif (size(A,1) ~= size(b,2)) || (size(b,1) ~= 1) || (size(A,1) ~= size(C,1)) || (size(C,1) ~= size(C,2))
        bst_report('Error', sProcess, [], 'The dimensions of the input matrices are incompatible.');
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



