function varargout = process_simulate_recordings( varargin )
% PROCESS_SIMULATE_RECORDINGS: Simulate source files based on some scouts.
%
% USAGE:  OutputFiles = process_simulate_recordings('Run', sProcess, sInputA)
 
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
% Authors: Francois Tadel, Guiomar Niso, 2013-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Simulate recordings from scouts';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Simulate'; 
    sProcess.Index       = 915;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Scouts?highlight=(simulate)#Menu:_Sources';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'matrix'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % === CLUSTERS
    sProcess.options.label1.Comment = '<B><U>Simulation</U></B>:';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.scouts.Comment = '';
    sProcess.options.scouts.Type    = 'scout';
    sProcess.options.scouts.Value   = {};
    % === SAVE SOURCES
    sProcess.options.savesources.Comment = 'Save full sources';
    sProcess.options.savesources.Type    = 'checkbox';
    sProcess.options.savesources.Value   = 1;
    % === ADD NOISE
    sProcess.options.label2.Comment = '<BR><B><U>Noise</U></B>:';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.isnoise.Comment = 'Add noise to the recordings';
    sProcess.options.isnoise.Type    = 'checkbox';
    sProcess.options.isnoise.Value   = 0;
    % === LEVEL OF NOISE (SNR1)
    sProcess.options.noise1.Comment = 'Level of random noise (SNR1):';
    sProcess.options.noise1.Type    = 'value';
    sProcess.options.noise1.Value   = {0, '', 2};
    % === LEVEL OF SENSOR NOISE (SNR2)
    sProcess.options.noise2.Comment = 'Level of sensor noise, based on noise covariance (SNR2):';
    sProcess.options.noise2.Type    = 'value';
    sProcess.options.noise2.Value   = {0, '', 2};
    % Notice
    sProcess.options.label3.Comment = ['<I>Src = Src + SNR1 .* (rand(size(Src))-0.5) .* max(abs(Src(:))); <BR>' ...
                                       'Rec = Rec + SNR2 .* get_noise_signals(NoiseCov);</I>'];
    sProcess.options.label3.Type    = 'label';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFiles = {};
    % Get scouts
    AtlasList = sProcess.options.scouts.Value;
    if isempty(AtlasList)
        bst_report('Error', sProcess, [], 'No scouts selected.');
        return;
    end
    % Get other options
    SaveSources = sProcess.options.savesources.Value;
    isNoise = sProcess.options.isnoise.Value;
    SNR1 = sProcess.options.noise1.Value{1};
    SNR2 = sProcess.options.noise2.Value{1};
    
    % === LOAD CHANNEL FILE / HEAD MODEL===
    % Get condition
    sStudy = bst_get('Study', sInput.iStudy);
    % Get channel file
    [sChannel, iStudyChannel] = bst_get('ChannelForStudy', sInput.iStudy);
    if isempty(sChannel)
        bst_report('Error', sProcess, [], ['No channel file available.' 10 'Please import a channel file in this study before running simulations.']);
        return;
    end
    % Get study channel
    sStudyChannel = bst_get('Study', iStudyChannel);
    % Check head model
    if isempty(sStudyChannel.iHeadModel)
        bst_report('Error', sProcess, [], ['No head model file available.' 10 'Please calculate a head model before running simulations.']);
        return;
    end
    % Load channel file
    ChannelMat = in_bst_channel(sChannel.FileName);
    % Load head model
    HeadModelFile = sStudyChannel.HeadModel(sStudyChannel.iHeadModel).FileName;
    HeadModelMat = in_bst_headmodel(HeadModelFile);
    % If no orientations: error
    if isempty(HeadModelMat.GridOrient)
        bst_report('Error', sProcess, [], 'No source orientations available in this head model.');
        return;
    end
    % Get all the MEG/EEG channels
    Modalities = {};
    if ~isempty(HeadModelMat.MEGMethod)
        Modalities{end+1} = 'MEG';
    end
    if ~isempty(HeadModelMat.EEGMethod)
        Modalities{end+1} = 'EEG';
    end
    if ~isempty(HeadModelMat.SEEGMethod)
        Modalities{end+1} = 'SEEG';
    end
    if ~isempty(HeadModelMat.ECOGMethod)
        Modalities{end+1} = 'ECOG';
    end
    iChannels = channel_find(ChannelMat.Channel, Modalities);
    
    % === LOAD CORTEX ===
    % Get surface from the head model
    SurfaceFile = HeadModelMat.SurfaceFile;
    % Get scout structures
    [sScouts, AtlasNames] = process_extract_scout('GetScoutsInfo', sProcess, sInput, SurfaceFile, AtlasList);
    if isempty(sScouts)
        return;
    end
    
    % === LOAD INPUT FILE ===
    % Read input file
    sMatrix = in_bst_matrix(sInput.FileName);
    % Check dimensions
    if (length(sScouts) ~= size(sMatrix.Value,1))
        bst_report('Error', sProcess, [], sprintf('The number of selected scouts (%d) does not match the number of signals (%d).', length(sScouts), size(sMatrix.Value,1)));
        return;
    end
    
    % === GENERATE SOURCE MATRIX ===
    % Number of sources depends on head model type
    switch (HeadModelMat.HeadModelType)
        case 'surface'
            % Force constrained sources
            nComponents = 1;
            % Apply the fixed orientation to the Gain matrix (normal to the cortex)
            HeadModelMat.Gain = bst_gain_orient(HeadModelMat.Gain, HeadModelMat.GridOrient);
        case 'volume'
            % Unconstrained sources
            nComponents = 3;
        case 'mixed'
            % Mixed source model
            nComponents = 0;
            % Calculate Vert2Grid and Grid2Source matrices
            [tmp, HeadModelMat] = process_inverse('SplitHeadModel', HeadModelMat);
            % Apply the fixed orientation to the Gain matrix (normal to the cortex)
            HeadModelMat.Gain = bst_gain_orient(HeadModelMat.Gain, HeadModelMat.GridOrient, HeadModelMat.GridAtlas);
    end
    % Number of sources = number of head model columns
    nSources = size(HeadModelMat.Gain,2);
    % Number of time points: copy from matrix file
    nTime = size(sMatrix.Value,2);
    % Initialize space matrix
    ImageGridAmp = sparse([],[],[],nSources, nTime, sum(cellfun(@length, {sScouts.Vertices}))*nTime);
    % Fill matrix
    for i = 1:length(sScouts)
        % Is this a volume or surface atlas
        isVolumeAtlas = panel_scout('ParseVolumeAtlas', AtlasNames{i});
        % Get source indices
        iSourceRows = bst_convert_indices(sScouts(i).Vertices, nComponents, HeadModelMat.GridAtlas, ~isVolumeAtlas);
        % Replicate scout values into all the sources
        ImageGridAmp(iSourceRows,:) = repmat(sMatrix.Value(i,:), length(iSourceRows), 1);
    end
    % Add noise SNR1 (random noise on the sources)
    if isNoise && (SNR1 > 0)
        ImageGridAmp = ImageGridAmp + SNR1 .* (rand(size(ImageGridAmp))-0.5) .* max(max(abs(ImageGridAmp)));
        strNoise = [',Nsn=', num2str(SNR1)];
    else
        strNoise = '';
    end
    % Set unit range to pAm
    ImageGridAmp = 1e-9 .* ImageGridAmp;
    
    % === GENERATE DATA MATRIX ===
    % Generate data matrix
    F = zeros(length(ChannelMat.Channel), nTime);
    F(iChannels,:) = HeadModelMat.Gain(iChannels,:) * ImageGridAmp;
    % Add noise SNR2 (sensor noise) 
    if isNoise && (SNR2 > 0)
        % Check if noise covariance matrix exists
        if isempty(sStudyChannel.NoiseCov) || isempty(sStudyChannel.NoiseCov.FileName)
            bst_report('Error', sProcess, [], 'No noise covariance matrix available, cannot add sensor noise.');
        else
            % Load the noise covariance matrix
            NoiseCovMat = load(file_fullpath(sStudyChannel.NoiseCov(1).FileName));
            % Compute noise signals from noise covariance matric
            xn = get_noise_signals (NoiseCovMat.NoiseCov(iChannels,iChannels), nTime);
            xnn = xn./max(max(xn)); % Noise signal between 0 and 1
            xns = xnn.*max(max(F(iChannels,:))); % Make the noise of similar amplitude than the signal
            % Add noise to recordings
            F(iChannels,:) = F(iChannels,:) + SNR2*xns; % Apply the SNR2
            strNoise = [strNoise, ',Nsc=', num2str(SNR2)];
        end
    end
    
    % === SAVE RECORDINGS ===
    % Create a new data file structure
    DataMat = db_template('datamat');
    DataMat.F           = F;
    DataMat.Comment     = sMatrix.Comment;
    DataMat.ChannelFlag = ones(length(ChannelMat.Channel), 1);
    DataMat.Time        = sMatrix.Time;
    DataMat.DataType    = 'recordings';
    DataMat.Device      = 'simulation';
    DataMat.nAvg        = 1;
    DataMat.Leff        = 1;
    DataMat.Events      = [];
    % Add history entry
    DataMat = bst_history('add', DataMat, 'simulate', ['Simulated from file: ' sInput.FileName]);
    % Output filename
    DataFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'data_sim');
    % Save on disk
    bst_save(DataFile, DataMat, 'v6');
    % Register in database
    db_add_data(sInput.iStudy, DataFile, DataMat);
    % Return data file
    OutputFiles{1} = DataFile;
    
    % === SAVE SOURCE FILE ===
    if SaveSources
        % Create a new source file structure
        ResultsMat = db_template('resultsmat');
        ResultsMat.ImagingKernel = [];
        ResultsMat.ImageGridAmp  = full(ImageGridAmp);
        ResultsMat.nComponents   = nComponents;
        ResultsMat.Comment       = sMatrix.Comment;
        ResultsMat.Function      = 'Simulation';
        ResultsMat.Time          = sMatrix.Time;
        ResultsMat.DataFile      = file_short(DataFile);
        ResultsMat.HeadModelFile = HeadModelFile;
        ResultsMat.HeadModelType = HeadModelMat.HeadModelType;
        if ~strcmpi(HeadModelMat.HeadModelType, 'surface')
            ResultsMat.GridLoc    = HeadModelMat.GridLoc;
            ResultsMat.GridOrient = HeadModelMat.GridOrient;
            ResultsMat.GridAtlas  = HeadModelMat.GridAtlas;
        end
        ResultsMat.ChannelFlag   = [];
        ResultsMat.GoodChannel   = iChannels;
        ResultsMat.SurfaceFile   = SurfaceFile;
        % Add history entry
        ResultsMat = bst_history('add', ResultsMat, 'simulate', ['Simulated from file: ' sInput.FileName]);
        % Output filename
        ResultsFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'results_sim');
        % Save on disk
        bst_save(ResultsFile, ResultsMat, 'v6');
        % Register in database
        db_add_data(sInput.iStudy, ResultsFile, ResultsMat);
    end
end



%% ===== GET NOISE SIGNALS =====
% GET_NOISE_SIGNALS: Generates noise signals from a noise covariance matrix
%
% INPUT:
%    - COV: Noise covariance matrix (M x M)
%    - Nsamples: Number of time points (length of noise signals)
% OUTPUT:
%    - xn: noise signals (M x Nsamples)
%
% DESCRIPTION: 
%     White noise covariance:
%     CXw = Xw * Xw' = Id
%     Gaussian white uncorrelated noise (randn)
%     Xw: (Nchannels x t)
% 
%     We have the following noise covariance matrix: C, and we decompose it into eigenvalues and eigenvectors:
%     C = v * D * v' = v * D^(1/2) * D^(1/2) * v'
%     Since C is symmetric, D is positive and D^(1/2) = D.^(1/2) (element by element)
% 
%     Therefore we define the noise signal we wanted to add as:
%     X = v * D^(1/2) * Xw
%     And obtain its covariance matrix as:
%     CX = Xw * Xw' = v * D^(1/2) * Xw * (v * D^(1/2) * Xw)' = v * D^(1/2) * Xw * XwT * D^(1/2)' * v'
%        = v * D^(1/2) * CXw * D^(1/2)' * v' = v * D^(1/2) * D^(1/2)' * v' = v * D * v' = C  
%     => Cov = xn * xn’ ./( Nsamples- 1)
%
% Author: Guiomar Niso, 2014
%
function xn = get_noise_signals(COV, Nsamples)
    [V,D] = eig(COV);

    % xn = (1/SNR) * V * D.^(1/2) * randn(size(COV,1),Nsamples);
    xn = V * D.^(1/2) * randn(size(COV,1),Nsamples);

    %%%%%%
    % Example:
    % SNR = 0.3;
    % Nsamples = 500;
    % xn = get_noise_signals (n.NoiseCov, Nsamples);
    % xnn = xn./max(max(xn));
    % xns = xnn.*max(max(s.F));
    % sn = s.F + SNR*xns;
    % s.F=sn;

    % figure(1); imagesc(n.NoiseCov); colorbar;
    % figure(2); imagesc(xn*xn' ./ (size(xn,2) - 1)); colorbar;
    % figure(3); imagesc(cov(xn)); colorbar;
    % See also noise extracted from recordings
end
