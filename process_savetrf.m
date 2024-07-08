function varargout = process_trf( varargin )
eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description of the process
    sProcess.Comment = 'Save Temporal Response Function Weights';
    sProcess.Category = 'Custom';
    sProcess.SubGroup = 'User';
    sProcess.Index = 1001;
    sProcess.isSeparator = 1;

    sProcess.InputTypes = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs = 1;
    sProcess.nMinFiles = 1;

    % Options: Sampling rate
    sProcess.options.samplingRate.Comment = 'Sampling Rate [Hz]:';
    sProcess.options.samplingRate.Type = 'value';
    sProcess.options.samplingRate.Value = {100, '', 0};

     % Options: tmin
    sProcess.options.tmin.Comment = 'tMin:';
    sProcess.options.tmin.Type = 'value';
    sProcess.options.tmin.Value = {100, '', 0};

     % Options: tmax
    sProcess.options.tmax.Comment = 'tMax:';
    sProcess.options.tmax.Type = 'value';
    sProcess.options.tmax.Value = {100, '', 0};

    % Options: Stimulus data file (user need to provide)
    sProcess.options.stimFile.Comment = 'Stimulus data file:';
    sProcess.options.stimFile.Type = 'filename';
    sProcess.options.stimFile.Value = {''};
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput)
    % Initialize output file list
    OutputFiles = {};

    % Install/load mTRF-Toolbox as plugin
    if ~exist('mTRFtrain', 'file')
        [isInstalled, errMsg] = bst_plugin('Install', 'mtrf');
        if ~isInstalled
            error(errMsg);
        end
    end

    % Check for exactly one input file
    if length(sInput) ~= 1
        bst_report('Error', sProcess, sInput, 'This process requires exactly one input file.');
        return;
    end

    EEGDataStruct = in_bst_data(sInput.FileName);
    if isempty(EEGDataStruct) || ~isfield(EEGDataStruct, 'F') || isempty(EEGDataStruct.F) || ~isnumeric(EEGDataStruct.F)
        bst_report('Error', sProcess, sInput, 'EEG data is empty or not a numeric matrix.');
        return;
    end
    EEGData = EEGDataStruct.F;

    % Load stimulus data
    stimFilePath = sProcess.options.stimFile.Value{1};
    if isempty(stimFilePath)
        bst_report('Error', sProcess, sInput, 'Stimulus data file missing.');
        return;
    end
    StimData = load(stimFilePath);

    % Dynamically determine the field name and extract stimulus data
    fieldNames = fieldnames(StimData);
    disp(fieldNames);
    if numel(fieldNames) ~= 1
        bst_report('Error', sProcess, sInput, 'Stimulus data file must contain exactly one field.');
        return;
    end
    stim = StimData.(fieldNames{1});

    % Get sampling rate from the process options
    fs = sProcess.options.samplingRate.Value{1};
    if isempty(fs) || ~isnumeric(fs) || isnan(fs)
        bst_report('Error', sProcess, sInput, 'Invalid sampling rate.');
        return;
    end

    tmin = sProcess.options.tmin.Value{1};
    if isempty(tmin) || ~isnumeric(tmin) || isnan(tmin)
        bst_report('Error', sProcess, sInput, 'Invalid tmin.');
        return;
    end

    tmax = sProcess.options.tmax.Value{1};
    if isempty(tmax) || ~isnumeric(tmax) || isnan(tmax)
        bst_report('Error', sProcess, sInput, 'Invalid tmax.');
        return;
    end

    lambda = 0.1;
    model = mTRFtrain(stim, EEGData,fs,1, tmin, tmax, lambda);
    modelSqueezed = squeeze(model.w(1,:,:));

    % Save the model to a new Brainstorm data file
    OutputMat = db_template('matrixmat');  
    OutputMat.Value = modelSqueezed;
    OutputMat.Comment = 'TRF Model Weights';  
    OutputFile = bst_process('GetNewFilename', bst_fileparts(sInput.FileName), 'matrix_trf_weights');

    bst_save(OutputFile, OutputMat, 'v6'); 
    db_add_data(sInput.iStudy, OutputFile, OutputMat);  
    OutputFiles{end+1} = OutputFile;

end

