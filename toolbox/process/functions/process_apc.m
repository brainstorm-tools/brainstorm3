function varargout = process_apc(varargin)
    eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    sProcess.Comment     = 'APC (Custom)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Frequency';
    sProcess.Index       = 656;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity';
    
    % Input / output
    sProcess.InputTypes  = {'data', 'results', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    
    % === Options for your code ===
    sProcess.options.label1.Comment = '<B>APC Parameters</B>';
    sProcess.options.label1.Type    = 'label';

    % Frequency range
    sProcess.options.fA.Comment = 'Frequency range (Hz)';
    sProcess.options.fA.Type    = 'timewindow';
    sProcess.options.fA.Value   = {[16, 250], 'Hz', []};

    % Epoch
    sProcess.options.epoch.Comment = 'Epoch time limits around peaks (s)';
    sProcess.options.epoch.Type    = 'timewindow';
    sProcess.options.epoch.Value   = {[-0.6, 0.6], 's', []};

    % Decomposition method
    sProcess.options.decomposition.Comment = 'Decomposition method';
    sProcess.options.decomposition.Type    = 'text';
    sProcess.options.decomposition.Value   = 'vmd_sym';

    % Show plots
    sProcess.options.diagm.Comment = 'Show plots';
    sProcess.options.diagm.Type    = 'checkbox';
    sProcess.options.diagm.Value   = 1;

    % Sampling rate
    sProcess.options.srate.Comment = 'Sampling rate (Hz)';
    sProcess.options.srate.Type    = 'value';
    sProcess.options.srate.Value   = {1000, 'Hz', []};

    % Data type
    sProcess.options.idataType.Comment = 'Type of input data';
    sProcess.options.idataType.Type    = 'text';
    sProcess.options.idataType.Value   = 'LFP';

    % Data length
    sProcess.options.dataLength.Comment = 'Length of data used for analysis (s)';
    sProcess.options.dataLength.Type    = 'timewindow';
    sProcess.options.dataLength.Value   = {[-1.5, 2], 's', []};

    % Surrogates
    sProcess.options.surrogates.Comment = 'Use surrogates';
    sProcess.options.surrogates.Type    = 'checkbox';
    sProcess.options.surrogates.Value   = 0;

    % Number of permutations
    sProcess.options.num_perm.Comment = 'Number of permutations';
    sProcess.options.num_perm.Type    = 'value';
    sProcess.options.num_perm.Value   = {1, '', []};

    % Phase bins
    sProcess.options.varargin.Comment = 'Number of phase bins';
    sProcess.options.varargin.Type    = 'value';
    sProcess.options.varargin.Value   = {18, '', []};
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput)

    sInputType = sInput.FileType;

    % Collect options
    OPTIONS.fA           = sProcess.options.fA.Value{1};
    OPTIONS.epoch        = sProcess.options.epoch.Value{1};
    OPTIONS.decomposition= sProcess.options.decomposition.Value;
    OPTIONS.diagm        = sProcess.options.diagm.Value;
    OPTIONS.srate        = sProcess.options.srate.Value{1};
    OPTIONS.idataType    = sProcess.options.idataType.Value;
    OPTIONS.dataLength   = sProcess.options.dataLength.Value{1};
    OPTIONS.surrogates   = sProcess.options.surrogates.Value;
    OPTIONS.num_perm     = sProcess.options.num_perm.Value{1};
    OPTIONS.numPhaseBins = sProcess.options.varargin.Value{1};

    % Load data based on input type
    switch sInputType
        
        case 'results'
            resultsIn = in_bst_results(sInput.FileName);
            data = resultsIn.ImageGridAmp;
            Time = resultsIn.Time;
        
        case 'data'
            dataIn = in_bst_data(sInput.FileName);
            data = dataIn.F;
            Time = dataIn.Time;
        
        case 'matrix'
            matIn = in_bst_matrix(sInput.FileName);
            data = matIn.Value;
            Time = matIn.Time;
        
        otherwise
            error('Unsupported input type.');
    end

    % Compute APC
    [A, B, C, D] = bst_apc(data, OPTIONS);

    Outputs = {A, B, C, D};
    Labels = {'A','B','C','D'};
    OutputFiles = {};

    sStudy = bst_get('Study', sInput.iStudy);

    for i = 1:4
        X = Outputs{i};

        switch sInputType
            case 'results'
                structMat = db_template('resultsmat');
                structMat.ImageGridAmp = [X,X];
                structMat.SurfaceFile = resultsIn.SurfaceFile;
                structMat.HeadModelFile = resultsIn.HeadModelFile;
                structMat.Time = [0,1];

            case 'data'
                structMat = db_template('datamat');
                structMat.F = X;
                structMat.Time = Time;

            case 'matrix'
                structMat = db_template('matrixmat');
                structMat.Value = X;
                structMat.Time = Time;
        end

        % Create filename
        OutputFile = bst_process('GetNewFilename', ...
                bst_fileparts(sStudy.FileName), ...
                ['apc_', Labels{i}]);

        % Save
        bst_save(OutputFile, structMat, 'v7');
        OutputFiles{end+1} = OutputFile;
    end
end

