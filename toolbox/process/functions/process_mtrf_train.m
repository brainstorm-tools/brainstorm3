function varargout = process_mtrf_train( varargin )
% process_mtrf_train: Fits an encoding/decoding model using mTRF-Toolbox

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
% Authors: Anna Zaidi, 2024
%          Raymundo Cassani, 2024

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description of the process
    sProcess.Comment     = 'Temporal Response Function Analyis';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Encoding';
    sProcess.Index       = 702;
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/MultivariateTemporalResponse';

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

    % Options: Plot result
    sProcess.options.plotResult.Comment = 'Plot result:';
    sProcess.options.plotResult.Type = 'checkbox';
    sProcess.options.plotResult.Value = 0;

    % Options: Channel number for plotting
    sProcess.options.channelNum.Comment = 'Channel number for plot:';
    sProcess.options.channelNum.Type = 'value';
    sProcess.options.channelNum.Value = {1, 'channels', 0};
    sProcess.options.channelNum.Conditions = {'plotResult', 1};
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

        return;
    end

    tmin = sProcess.options.tmin.Value{1};
    if isempty(tmin) || ~isnumeric(tmin) || isnan(tmin)
        bst_report('Error', sProcess, sInput, 'Invalid tmin.');
        return;
    end
    % Sampling frequency (Hz)
    fs = 1 ./ (DataMat.Time(2) - DataMat.Time(1));
    nSamples = size(DataMat.F,2);

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

    % Plotting, if requested
    if sProcess.options.plotResult.Value
        channelNum = sProcess.options.channelNum.Value{1};
        % Plot STRF
        figure
        subplot(2,2,1), mTRFplot(model,'mtrf','all',channelNum,[tmin,tmax]);
        title('Speech STRF (Fz)'), ylabel('Frequency band'), xlabel('')

        % Plot GFP
        subplot(2,2,2), mTRFplot(model,'mgfp','all','all',[tmin,tmax]);
        title('Global Field Power'), xlabel('')

        % Plot TRF
        subplot(2,2,3), mTRFplot(model,'trf','all',channelNum,[tmin,tmax]);
        title('Speech TRF (Fz)'), ylabel('Amplitude (a.u.)')

        % Plot GFP
        subplot(2,2,4), mTRFplot(model,'gfp','all','all',[tmin,tmax]);
        title('Global Field Power')
    end

end
