function varargout = process_simulate_recordings( varargin )
% PROCESS_SIMULATE_RECORDINGS: Simulate source files based on some scouts.
%
% USAGE:  OutputFiles = process_simulate_recordings('Run', sProcess, sInputA)
 
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
% Authors: Guiomar Niso, 2013-2016
%          Francois Tadel, 2013-2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Simulate recordings from scouts';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Simulate'; 
    sProcess.Index       = 916;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Simulations#Simulate_MEG.2FEEG_from_synthetic_dipoles';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'matrix'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % Notice inputs
    sProcess.options.label1.Comment = ['<FONT COLOR="#777777">&nbsp;- N signals (constrained) or 3*N signals (unconstrained)<BR>' ...
                                       '&nbsp;- N scouts: selected below</FONT>'];
    sProcess.options.label1.Type    = 'label';
    sProcess.options.label1.Group   = 'input';
    % Notice algorithm
    sProcess.options.label2.Comment = ['<FONT COLOR="#777777">Algorithm:<BR>' ...
                                       '&nbsp;- Create an empty source file with zeros at every vertex<BR>' ...
                                       '&nbsp;- Assign each signal #i to all the vertices within scout #i<BR>' ... 
                                       '&nbsp;- Add random noise to the source maps (optional):<BR>' ...
                                       '&nbsp;&nbsp;&nbsp;<I>Src = Src + SNR1 .* (rand(size(Src))-0.5) .* max(abs(Src(:)));</I><BR>' ...
                                       '&nbsp;- Multiply simulated sources with forward model to obtain recordings<BR>' ...
                                       '&nbsp;- Add sensor noise, based on noise covariance (optional):<BR>' ...
                                       '&nbsp;&nbsp;&nbsp;<I>Rec = Rec + SNR2 .* get_noise_signals(NoiseCov);</I><BR></FONT>'];
    sProcess.options.label2.Type    = 'label';

    % === SCOUTS
    sProcess.options.scouts.Comment = '';
    sProcess.options.scouts.Type    = 'scout';
    sProcess.options.scouts.Value   = {};
    sProcess.options.scouts.Group   = 'input';
    % === ADD NOISE
    sProcess.options.isnoise.Comment = 'Add noise';
    sProcess.options.isnoise.Type    = 'checkbox';
    sProcess.options.isnoise.Value   = 0;
    sProcess.options.isnoise.Controller = 'Noise';
    % === LEVEL OF NOISE (SNR1)
    sProcess.options.noise1.Comment = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Level of source noise (SNR1):';
    sProcess.options.noise1.Type    = 'value';
    sProcess.options.noise1.Value   = {0, '', 2};
    sProcess.options.noise1.Class   = 'Noise';
    % === LEVEL OF SENSOR NOISE (SNR2)
    sProcess.options.noise2.Comment = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Level of sensor noise (SNR2):';
    sProcess.options.noise2.Type    = 'value';
    sProcess.options.noise2.Value   = {0, '', 2};
    sProcess.options.noise2.Class   = 'Noise';
    % === SAVE SOURCES
    sProcess.options.savesources.Comment = 'Save full sources <FONT COLOR="#777777">(see process <I>Full source maps from scouts</I>)</FONT>';
    sProcess.options.savesources.Type    = 'checkbox';
    sProcess.options.savesources.Value   = 1;
    sProcess.options.savesources.Group   = 'output';
    % === SAVE DATA 
    sProcess.options.savedata.Comment = 'Save recordings';
    sProcess.options.savedata.Type    = 'checkbox';
    sProcess.options.savedata.Value   = 1;
    sProcess.options.savedata.Hidden  = 1;
    % === HEAD MODEL (when simulated on the fly by process_simulate_dipole)
    sProcess.options.headmodel.Comment = 'Head model file: ';
    sProcess.options.headmodel.Type    = 'label';
    sProcess.options.headmodel.Value   = [];
    sProcess.options.headmodel.Hidden  = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFiles = {};
    % Two options: using 1) fixed dipoles in input or 2) source model from the database
    isFixedDipoles = isfield(sProcess.options, 'headmodel') && isfield(sProcess.options.headmodel, 'Value') && ~isempty(sProcess.options.headmodel.Value);
    % Get scouts
    if ~isFixedDipoles
        AtlasList = sProcess.options.scouts.Value;
        if isempty(AtlasList)
            bst_report('Error', sProcess, [], 'No scouts selected.');
            return;
        end
    end
    % Get other options
    SaveSources = sProcess.options.savesources.Value;
    SaveData = sProcess.options.savedata.Value;
    isNoise = sProcess.options.isnoise.Value;
    SNR1 = sProcess.options.noise1.Value{1};
    SNR2 = sProcess.options.noise2.Value{1};
    
    % === LOAD CHANNEL FILE ===
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
    % Load channel file
    ChannelMat = in_bst_channel(sChannel.FileName);
    
    % === LOAD HEAD MODEL ===
    % Use headmodel in input:  Simulating from dipoles
    if isFixedDipoles
        HeadModelFile = [];
        HeadModelMat = sProcess.options.headmodel.Value;
    % Load default subject's headmodel:  Simulating from sources
    else
        % Check head model
        if isempty(sStudyChannel.iHeadModel)
            bst_report('Error', sProcess, [], ['No head model file available.' 10 'Please calculate a head model before running simulations.']);
            return;
        end
        % Load headmodel
        HeadModelFile = sStudyChannel.HeadModel(sStudyChannel.iHeadModel).FileName;
        HeadModelMat = in_bst_headmodel(HeadModelFile);
    end
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
    
    % === GET SIMULATED SCOUTS ===
    if ~isFixedDipoles
        % Get surface from the head model
        SurfaceFile = HeadModelMat.SurfaceFile;
        % Get scout structures
        [sScouts, AtlasNames] = process_extract_scout('GetScoutsInfo', sProcess, sInput, SurfaceFile, AtlasList);
        if isempty(sScouts)
            return;
        end
        % Accept only scouts from the same atlas
        if (length(AtlasNames) > 1) && any(~strcmpi(AtlasNames, AtlasNames{1}))
            bst_report('Error', sProcess, [], 'All the scouts in input must come from the same atlas.');
            return;
        end
        % Check if this is a volume atlas
        isVolumeAtlas = panel_scout('ParseVolumeAtlas', AtlasNames{1});
    end
    
    % === LOAD INPUT FILE ===
    % Read input file
    sMatrix = in_bst_matrix(sInput.FileName);
    
    % === GENERATE SOURCE MATRIX ===
    % Number of sources depends on head model type
    switch (HeadModelMat.HeadModelType)
        case 'surface'
            % Constrained orientation: one scout = one signal
            if isFixedDipoles || (length(sScouts) == size(sMatrix.Value,1))
                nComponents = 1;
                % Apply the fixed orientation to the Gain matrix (normal to the cortex)
                HeadModelMat.Gain = bst_gain_orient(HeadModelMat.Gain, HeadModelMat.GridOrient);
            % Unconstrained orientation: one scout = three signal
            elseif (3*length(sScouts) == size(sMatrix.Value,1))
                nComponents = 3;
            else
                bst_report('Error', sProcess, [], sprintf('The number of selected scouts (%d) does not match the number of signals (%d or %d).', length(sScouts), size(sMatrix.Value,1), 3*size(sMatrix.Value,1)));
                return;
            end
            % Check volume/surface
            if ~isFixedDipoles && isVolumeAtlas
                bst_report('Error', sProcess, [], 'You cannot use a volume scout with a surface head model.');
                return;
            end

        case 'volume'
            % Check dimensions
            if (3*length(sScouts) ~= size(sMatrix.Value,1))
                bst_report('Error', sProcess, [], sprintf([...
                    'With unconstrained source models, each scouts needs three signals, one for each orientation (x,y,z):\n' ...
                    'Signal(1)=>Scout1.x, Signal(2)=>Scout1.y, Signal(3)=>Scout1.z, Signal(4)=>Scout2.x, ...\n\n' ...
                    'The number of expected signals (3*Nscouts=%d) does not match the number of signals in the file (%d).'], 3*length(sScouts), size(sMatrix.Value,1)));
                return;
            end
            % Check volume/surface
            if ~isVolumeAtlas
                bst_report('Error', sProcess, [], 'You cannot use a surface scout with a volume head model.');
                return;
            end
            % Unconstrained sources
            nComponents = 3;
        case 'mixed'
            error('Mixed head models are not supported by this process.');
%             % Mixed source model
%             nComponents = 0;
%             % Calculate Vert2Grid and Grid2Source matrices
%             [tmp, HeadModelMat] = process_inverse('SplitHeadModel', HeadModelMat);
%             % Apply the fixed orientation to the Gain matrix (normal to the cortex)
%             HeadModelMat.Gain = bst_gain_orient(HeadModelMat.Gain, HeadModelMat.GridOrient, HeadModelMat.GridAtlas);
    end   
    % Number of sources = number of head model columns
    nSources = size(HeadModelMat.Gain,2);
    % Number of time points: copy from matrix file
    nTime = size(sMatrix.Value,2);
    
    % If not using a fixed list of dipoles: rebuild full source maps
    if ~isFixedDipoles
        % Initialize space matrix
        ImageGridAmp = sparse([],[],[],nSources, nTime, sum(cellfun(@length, {sScouts.Vertices}))*nTime);
        % Fill matrix
        for i = 1:length(sScouts)
            % Get source indices
            iSourceRows = bst_convert_indices(sScouts(i).Vertices, nComponents, HeadModelMat.GridAtlas, ~isVolumeAtlas);
            % Constrained models: One scout x One signal
            if (nComponents == 1)   
                % Replicate signal values for all the dipoles in the scout
                ImageGridAmp(iSourceRows,:) = repmat(sMatrix.Value(i,:), length(iSourceRows), 1);
            % Unconstrained models: One scout x One orientation (x,y,z) = one signal
            elseif (nComponents == 3)
                for dim = 1:3
                    iSignal = 3*(i-1) + dim;
                    % Replicate signal values for all the dipoles in the scout (with <dim> orientation only)
                    ImageGridAmp(iSourceRows(dim:3:end),:) = repmat(sMatrix.Value(iSignal,:), length(iSourceRows)/3, 1);
                end
            end
        end

    % Not using scouts: Source map = list of signals in input
    else
        ImageGridAmp = sMatrix.Value;
    end

    % Add noise SNR1 (random noise on the sources)
    if isNoise && (SNR1 > 0)
        ImageGridAmp = ImageGridAmp + SNR1 .* (rand(size(ImageGridAmp))-0.5) .* max(max(abs(ImageGridAmp)));
        strNoise = [' SNR1=', num2str(SNR1)];
    else
        strNoise = '';
    end
    % Set unit range to pAm
    if max(abs(ImageGridAmp(:)) > 1e-3)
        ImageGridAmp = 1e-9 .* ImageGridAmp;
    end
    
    % === GENERATE DATA MATRIX ===
    if SaveData
        % Generate data matrix
        F = zeros(length(ChannelMat.Channel), nTime);
        F(iChannels,:) = HeadModelMat.Gain(iChannels,:) * ImageGridAmp;
        % Add noise SNR2 (sensor noise) 
        if isNoise && (SNR2 > 0)
            % Check if noise covariance matrix exists
            if isempty(sStudyChannel.NoiseCov) || isempty(sStudyChannel.NoiseCov(1).FileName)
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
                strNoise = [strNoise, ' SNR2=', num2str(SNR2)];
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
        DataMat = bst_history('add', DataMat, 'simulate', ['Simulated from file: ' sInput.FileName, strNoise]);
        % Output filename
        DataFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'data_sim');
        % Save on disk
        bst_save(DataFile, DataMat, 'v6');
        % Register in database
        db_add_data(sInput.iStudy, DataFile, DataMat);
        % Return data file
        OutputFiles = {DataFile};
    end
    
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
        if SaveData
            ResultsMat.DataFile = file_short(DataFile);
        else
            ResultsMat.DataFile = [];
        end
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
        % Return as output file if not saving data
        if ~SaveData
            OutputFiles = {ResultsFile};
        end
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
