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
    sProcess.OutputTypes = {'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/MultivariateTemporalResponse';
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data', 'raw'};
    % Event name
    sProcess.options.labelevt.Comment  = '<HTML><I><FONT color="#777777">For multiple events: separate them with commas</FONT></I>';
    sProcess.options.labelevt.Type     = 'label';
    sProcess.options.eventname.Comment = 'Event names: ';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = '';
    % Minimum time lag
    sProcess.options.tmin.Comment = 'Minimun time lag:';
    sProcess.options.tmin.Type    = 'value';
    sProcess.options.tmin.Value   = {-100, 'ms', 0};
    % Maximum time lag
    sProcess.options.tmax.Comment = 'Maximum time lag:';
    sProcess.options.tmax.Type    = 'value';
    sProcess.options.tmax.Value   = {100, 'ms', 0};
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

    % ===== GET OPTIONS =====
    % Sensor types
    sensorTypes = [];
    if isfield(sProcess.options, 'sensortypes') && ~isempty(sProcess.options.sensortypes) && ~isempty(sProcess.options.sensortypes.Value)
        sensorTypes = sProcess.options.sensortypes.Value;
    end
    % Get event names
    evtNames = strtrim(str_split(sProcess.options.eventname.Value, ',;'));
    if isempty(evtNames)
        bst_report('Error', sProcess, [], 'No events were provided.');
        return;
    end
    % Get minimum time lag (ms)
    tmin = sProcess.options.tmin.Value{1};
    if isempty(tmin) || ~isnumeric(tmin) || isnan(tmin)
        bst_report('Error', sProcess, sInput, 'Invalid tmin.');
        return;
    end
    tmin = tmin * 1000;
    % Get maximum time lag (ms)
    tmax = sProcess.options.tmax.Value{1};
    if isempty(tmax) || ~isnumeric(tmax) || isnan(tmax)
        bst_report('Error', sProcess, sInput, 'Invalid tmax.');
        return;
    end
    tmax = tmax * 1000;
    % Check for exactly one input file
    if length(sInput) ~= 1
        bst_report('Error', sProcess, sInput, 'This process requires exactly one input file.');
        return;
    end

    % Load file 
    DataMat = in_bst_data(sInput.FileName);
    if isempty(DataMat) || ~isfield(DataMat, 'F') || isempty(DataMat.F) || ~isnumeric(DataMat.F)
        bst_report('Error', sProcess, sInput, 'EEG data is empty or not a numeric matrix.');
        return;
    end
    % Sampling frequency (Hz)
    fs = 1 ./ (DataMat.Time(2) - DataMat.Time(1));
    nSamples = size(DataMat.F,2);
    % Load channel file
    ChannelFile = sInput.ChannelFile;
    ChannelMat = in_bst_channel(ChannelFile);

    % Select sensors
    if ~isempty(sensorTypes)
        % Find selected channels
        iChannels = channel_find(ChannelMat.Channel, sensorTypes);
        if isempty(iChannels)
            bst_report('Error', sProcess, sInput, 'Could not load any sensor from the input file. Check the sensor selection.');
            return;
        end
        % Keep only selected channels
        F = DataMat.F(iChannels, :);
        channelNames = {ChannelMat.Channel(iChannels).Name}';
    else
        F = DataMat.F;
        channelNames = {ChannelMat.Channel.Name}';
    end

    % mTRF train for each event
    for iEvent = 1 : length(evtNames)
        stim = zeros(nSamples, 1);
        iEvt = find(strcmpi({DataMat.Events.label}, evtNames{iEvent}));
        if isempty(iEvt)
            continue
        end
        % Event must be simple event
        if size(DataMat.Events(iEvt).times, 1) ~= 1
            bst_report('Warning', sProcess, sInputs, ['Events must be simple. Skipping event: "' evtNames{iEvent} '"' ]);            
            continue;
        end
        % Event occurrences (in samples)
        iEvtOccur = bst_closest(DataMat.Events(iEvt).times, DataMat.Time);
        stim(iEvtOccur) = 1;

        % mTRF train
        lambda = 0.1;
        model = mTRFtrain(stim, F', fs, 1, tmin, tmax, lambda);

        % Store weights of the mTRF model in a matrix file
        OutputMat             = db_template('matrixmat');
        OutputMat.Comment     = ['TRF Model Weights: ' evtNames{iEvent}];
        OutputMat.Time        = squeeze(model.t);
        OutputMat.Value       = squeeze(model.w(1,:,:))';
        OutputMat.Description = channelNames;
        % Save and add to database
        OutputFile = bst_process('GetNewFilename', bst_fileparts(sInput.FileName), 'matrix_trf_weights');        
        bst_save(OutputFile, OutputMat, 'v6');
        db_add_data(sInput.iStudy, OutputFile, OutputMat);

        OutputFiles{end+1} = OutputFile;
    end
end
