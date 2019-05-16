function varargout = process_inverse_2018( varargin )
% PROCESS_INVERSE_2018: Compute an inverse model.

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
% Authors: Francois Tadel, 2012-2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % ===== PROCESS =====
    % Description the process
    sProcess.Comment     = 'Compute sources [2018]';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Sources';
    sProcess.Index       = 326;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/SourceEstimation';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'results', 'results'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % Option: Output
    sProcess.options.output.Comment = {'Kernel only: shared', 'Kernel only: one per file', 'Full results: one per file'};
    sProcess.options.output.Type    = 'radio';
    sProcess.options.output.Value   = 1;
    % Options: MNE options
    sProcess.options.inverse.Comment = {'panel_inverse_2018', 'Source estimation options: '};
    sProcess.options.inverse.Type    = 'editpref';
    sProcess.options.inverse.Value   = bst_inverse_linear_2018();
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    
    % ===== GET OPTIONS =====
    % Default inverse options
    OPTIONS = Compute();
    % Get options edited by the user
    OPTIONS = struct_copy_fields(OPTIONS, sProcess.options.inverse.Value, 1);
    % Output
    switch (sProcess.options.output.Value)
        % Kernel only: shared
        case 1      
            [sChannels, iStudies] = bst_get('ChannelForStudy', unique([sInputs.iStudy]));
            iStudies = unique(iStudies);
            iDatas   = [];
            OPTIONS.ComputeKernel = 1;
        % Kernel only: one per file
        case 2      
            iStudies = [sInputs.iStudy];
            iDatas   = [sInputs.iItem];
            OPTIONS.ComputeKernel = 1;
        % Full results: one per file
        case 3
            iStudies = [sInputs.iStudy];
            iDatas   = [sInputs.iItem];
            OPTIONS.ComputeKernel = 0;
    end
    % No messages
    OPTIONS.DisplayMessages = 0;

    % ===== START COMPUTATION =====
    % Call head modeler
    [AllFiles, errMessage] = Compute(iStudies, iDatas, OPTIONS);
    % Report errors
    if isempty(AllFiles) && ~isempty(errMessage)
        bst_report('Error', sProcess, sInputs, errMessage);
        return;
    elseif ~isempty(errMessage)
        bst_report('Warning', sProcess, sInputs, errMessage);
    end
    % For shared kernels: Return only the source files corresponding to the recordings that were in input
    if isempty(iDatas)
        % Loop on the output files (all links): find the ones that match the input
        for iFile = 1:length(AllFiles)
            % Resolve link: get data file
            [ResFile, DataFile] = file_resolve_link(AllFiles{iFile});
            % Find one that matches the inputs
            iInput = find(file_compare({sInputs.FileName}, file_short(DataFile)));
            % If founf: add to the output files
            if ~isempty(iInput)
                OutputFiles{end+1} = AllFiles{iFile};
            end
        end
    else
        OutputFiles = AllFiles;
    end
end



%% ===== COMPUTE INVERSE SOLUTION =====
% USAGE:      OPTIONS = Compute()
%         OutputFiles = Compute(iStudies, iDatas, OPTIONS)
%
% Authors: Sylvain Baillet, October 2002
%          Esen Kucukaltun-Yildirim, 2004
%          Syed Ashrafulla, John Mosher, Rey Ramirez, 2009-2012
%          Francois Tadel, John Mosher, 2009-2018
%
function [OutputFiles, errMessage] = Compute(iStudies, iDatas, OPTIONS)
    % Initialize returned variables
    OutputFiles = {};
    errMessage = [];
    % Default options settings
    Def_OPTIONS = struct(...
        'InverseMethod',       'minnorm', ... % A string that specifies the imaging method
        'InverseMeasure',      'dspm2018', ...
        'SourceOrient',        'fixed', ...
        'DataTypes',           [], ...     % Cell array of strings: list of modality to use for the reconstruction (MEG, MEG GRAD, MEG MAG, EEG)
        'Comment',             '', ...     % Inverse solution description (optional)
        'DisplayMessages',     1, ...
        'ComputeKernel',       1);         % If 1, compute MN kernel to be applied subsequently to data instead of full ImageGridAmp array
    % Return default options
    if (nargin < 2)
        OutputFiles = Def_OPTIONS;
        return;
    end
    % Use default options
    if (nargin < 3) || isempty(OPTIONS)
        OPTIONS = Def_OPTIONS;
    else
        % Check field names of passed OPTIONS and fill missing ones with default values
        OPTIONS = struct_copy_fields(OPTIONS, Def_OPTIONS, 0);
    end
    
    
    %% ===== GET INPUT INFORMATION =====
    isShared = isempty(iDatas);
    % Get all the study structures
    sStudies = bst_get('Study', unique(iStudies));
    % Get channel studies
    if isShared
        sChanStudies = sStudies;
    else
        [tmp, iChanStudies] = bst_get('ChannelForStudy', unique(iStudies));
        sChanStudies = bst_get('Study', iChanStudies);
    end
    % Check that there are channel files available
    if any(cellfun(@isempty, {sChanStudies.Channel}))
        errMessage = 'No channel file available.';
        return;
    end
    % Check head model
    if any(cellfun(@isempty, {sChanStudies.HeadModel}))
        errMessage = 'No head model available.';
        return;
    end
    % Check noise covariance
    if any(cellfun(@isempty, {sChanStudies.NoiseCov}))
        errMessage = 'No noise covariance matrix available.';
        return;
    end
    % Loop through all the channel files to find the available modalities and head model types
    AllMod = {};
    HeadModelType = 'surface';
    MEGMethod = [];
    nSamplesNoise = [];
    nSamplesData  = [];
    for i = 1:length(sChanStudies)
        AllMod = union(AllMod, sChanStudies(i).Channel.DisplayableSensorTypes);
        if isempty(sChanStudies(i).HeadModel(sChanStudies(i).iHeadModel).MEGMethod)
            AllMod = setdiff(AllMod, {'MEG GRAD','MEG MAG','MEG'});
        end
        if isempty(sChanStudies(i).HeadModel(sChanStudies(i).iHeadModel).EEGMethod)
            AllMod = setdiff(AllMod, {'EEG'});
        end
        if isempty(sChanStudies(i).HeadModel(sChanStudies(i).iHeadModel).ECOGMethod)
            AllMod = setdiff(AllMod, {'ECOG'});
        end
        if isempty(sChanStudies(i).HeadModel(sChanStudies(i).iHeadModel).SEEGMethod)
            AllMod = setdiff(AllMod, {'SEEG'});
        end
        if ~strcmpi(sChanStudies(i).HeadModel(sChanStudies(i).iHeadModel).HeadModelType, 'surface')
            HeadModelType = sChanStudies(i).HeadModel(sChanStudies(i).iHeadModel).HeadModelType;
        end
        if ~isempty(sChanStudies(i).HeadModel(sChanStudies(i).iHeadModel).MEGMethod) && isempty(MEGMethod)
            MEGMethod = sChanStudies(i).HeadModel(sChanStudies(i).iHeadModel).MEGMethod;
        end
        % First file only: Load the number of samples from the covariance files
        if (i == 1)
            % Noise covariance
            if (length(sChanStudies(i).NoiseCov) >= 1) && ~isempty(sChanStudies(i).NoiseCov(1).FileName)
                covMat = load(file_fullpath(sChanStudies(i).NoiseCov(1).FileName), 'nSamples');
                if isfield(covMat, 'nSamples') && ~isempty(covMat.nSamples)
                    nSamplesNoise = covMat.nSamples;
                end
            end
            % Data covariance
            if (length(sChanStudies(i).NoiseCov) >= 2) && ~isempty(sChanStudies(i).NoiseCov(2).FileName)
                covMat = load(file_fullpath(sChanStudies(i).NoiseCov(2).FileName), 'nSamples');
                if isfield(covMat, 'nSamples') && ~isempty(covMat.nSamples)
                    nSamplesData = covMat.nSamples;
                end
            end
        end
    end
    % Keep only MEG and EEG
    if any(ismember(AllMod, {'MEG GRAD','MEG MAG'}))
        AllMod = intersect(AllMod, {'MEG GRAD', 'MEG MAG', 'EEG', 'ECOG', 'SEEG'});
    else
        AllMod = intersect(AllMod, {'MEG', 'EEG', 'ECOG', 'SEEG'});
    end
    % Check that at least one modality is available
    if isempty(AllMod)
        errMessage = 'No valid sensor types to estimate sources: please calculate an appropriate headmodel.';
        return;
    end

    
    %% ===== SELECT INVERSE METHOD =====
    % Select method
    if OPTIONS.DisplayMessages
        % Options dialog window
        sMethod = gui_show_dialog('Compute sources', @panel_inverse_2018, 1, [], AllMod, isShared, HeadModelType, nSamplesNoise, nSamplesData);
        if isempty(sMethod)
            return;
        end
        % Override default options
        OPTIONS = struct_copy_fields(OPTIONS, sMethod, 1);
        
        % === BRAINENTROPY MEM ===
        % Display additional option windows
        if strcmpi(OPTIONS.InverseMethod, 'mem')
            % No data files found
            if isShared
                errMessage = 'Cannot compute shared kernels with this method.';
                return
            end
            % Default options
            MethodOptions = be_main();
            % Interface to edit options
            MethodOptions = gui_show_dialog('MEM options', @panel_brainentropy, [], [], MethodOptions);
            % Add fields that are not defined by the options of the MEM interface
            if ~isempty(MethodOptions)
                switch (HeadModelType)
                    case {'surface', 'ImageGrid'}
                        MethodOptions.SourceOrient{1} = 'fixed';
                    case 'volume'
                        MethodOptions.SourceOrient{1} = 'free';
                        MethodOptions.flagSourceOrient = [0 0 2 0];
                end
            end
            % Canceled by user
            if isempty(MethodOptions)
                return
            end
            % Add options to list
            OPTIONS = struct_copy_fields(OPTIONS, MethodOptions, 1);
        end
    end
    % If no MEG and no EEG selected
    if isempty(OPTIONS.DataTypes)
        errMessage = 'Please select at least one modality.';
        return;
    end
    % Tags corresponding to the different methods
    methodTag = panel_inverse_2018('GetMethodComment', OPTIONS.InverseMethod, OPTIONS.InverseMeasure);
    

    %% ===== COMMENT =====
    % Base comment: "METHOD: MODALITIES"
    if isempty(OPTIONS.Comment)
        OPTIONS.Comment = [methodTag, ': ' GetModalityComment(OPTIONS.DataTypes)];
    end
    % Add source orientation option string
    strOptions = '';
    if isempty(OPTIONS.SourceOrient)
        strOptions = 'Mixed';
    elseif ~strcmpi(OPTIONS.InverseMethod, 'mem')
        switch (OPTIONS.SourceOrient{1})
            case 'fixed',      strOptions = 'Constr';
            case 'loose',      strOptions = 'Loose';
            case 'free',       strOptions = 'Unconstr';
        end
    end
    % Add Kernel/Full option string
    if ~OPTIONS.ComputeKernel
        if ~isempty(strOptions)
            strOptions = [',' strOptions];
        end
        strOptions = ['Full', strOptions];
    end
    % Final comment
    if ~isempty(strOptions)
        OPTIONS.Comment = [OPTIONS.Comment, '(', strOptions, ')'];
    end
    
    
    %% ===== LOOP ON INPUT FILES =====
    % Initializations
    initOPTIONS = OPTIONS;
    % Display progress bar
    bst_progress('start', 'Compute sources', 'Initialize...', 0, 3*length(iStudies) + 1);
    % Process each input
    for iEntry = 1:length(iStudies)
        OPTIONS = initOPTIONS;
        
        % ===== LOAD CHANNEL FILE =====
        bst_progress('text', 'Reading channel information...');
        % Get study structure
        iStudy = iStudies(iEntry);
        sStudy = bst_get('Study', iStudy);
        % Check if default study
        isDefaultStudy = strcmpi(sStudy.Name, bst_get('DirDefaultStudy'));
        % Get channel file for study
        [sChannel, iStudyChannel] = bst_get('ChannelForStudy', iStudy);
        ChannelFile = sChannel.FileName;
        % Load channel file
        ChannelMat = in_bst_channel(ChannelFile, 'Channel', 'Projector');

        % ===== LOAD DATA FILES =====
        bst_progress('text', 'Getting bad channels...');
        % Single inverse file
        if ~isShared
            % Get only one file
            DataFile = sStudy.Data(iDatas(iEntry)).FileName;
            % Load data file info (only 'mem' requires the recordings to be loaded here)
            if strcmpi(OPTIONS.InverseMethod, 'mem')
                DataMat = in_bst_data(DataFile, 'ChannelFlag', 'Time', 'nAvg', 'F');
            else
                DataMat = in_bst_data(DataFile, 'ChannelFlag', 'Time', 'nAvg');
            end
            ChannelFlag = DataMat.ChannelFlag;
            nAvg        = DataMat.nAvg;
            Time        = DataMat.Time;
            % Is it a Raw file?
            isRaw = strcmpi(sStudy.Data(iDatas(iEntry)).DataType, 'raw');
        % Shared inverse kernel
        else
            % Get all the dependent data files
            [iRelatedStudies, iRelatedData] = bst_get('DataForStudy', iStudy);
            % List all the data files
            nAvgAll     = zeros(1,length(iRelatedStudies));
            BadChannels = [];
            nChannels   = [];
            for i = 1:length(iRelatedStudies)
                % Get data file
                sStudyRel = bst_get('Study', iRelatedStudies(i));
                DataFull = file_fullpath(sStudyRel.Data(iRelatedData(i)).FileName);
                % Read bad channels and nAvg
                DataMat = load(DataFull, 'ChannelFlag', 'nAvg');
                if isfield(DataMat, 'nAvg') && ~isempty(DataMat.nAvg)
                    nAvgAll(i) = DataMat.nAvg;
                else
                    nAvgAll(i) = 1;
                end
                % Count number of times the channe is bad
                if isempty(BadChannels)
                    BadChannels = double(DataMat.ChannelFlag < 0);
                else
                    BadChannels = BadChannels + (DataMat.ChannelFlag < 0);
                end
                % Channel number
                if isempty(nChannels)
                    nChannels = length(DataMat.ChannelFlag);
                elseif (nChannels ~= length(DataMat.ChannelFlag))
                    errMessage = 'All data files must have the same number of channels.';
                    continue;
                end
            end
            % Get list of sensors selected for inversion
            iChanInv = good_channel(ChannelMat.Channel, [], OPTIONS.DataTypes);
            % Mark all the channels that are not selected here as good
            BadChannels(setdiff(1:length(BadChannels), iChanInv)) = 0;
                    
            % === CHECK nAVG ===
            % if ~isempty(iRelatedStudies) && any(nAvgAll ~= nAvgAll(1)) && isFirstWarnAvg
            %     % Display a warning in a dialog window
            %     if OPTIONS.DisplayMessages
            %         isConfirm = java_dialog('confirm', ...
            %             ['Warning: You should estimate separataley the sources for the averages and the single trials.', 10 ...
            %             'The level of noise in the files might be different, this may cause inaccurate results.' 10 10 ... 
            %             ' - For several averages: compute sources separately for each file.' 10 ...
            %             ' - For single trials: compute a shared solution, and move the averages in another condition.' 10 10 ...
            %             'Ignore this warning and compute sources ?'], 'Compute sources');
            %         if ~isConfirm
            %             return
            %         end
            %     % Return a warning message
            %     else
            %         errMessage = [errMessage 'Mixing averages and single trials. Result might be inaccurate.' 10];
            %     end
            %     isFirstWarnAvg = 0;
            % end
            nAvg = min([nAvgAll 1]);
            
            % === BAD CHANNELS ===
            if any(BadChannels)
                % Display a warning in a dialog window
                if OPTIONS.DisplayMessages
                    % Build list of bad channels
                    strBad = '';
                    iBad = find(BadChannels);
                    for i = 1:length(iBad)
                        strBad = [strBad sprintf('%d(%d)   ', iBad(i), BadChannels(iBad(i)))];
                        if (mod(i,6) == 0)
                            strBad = [strBad 10];
                        end
                    end
                    % Ask user confirmation
                    [res, isCancel] = java_dialog('input', ...
                        ['Some channels are bad in at least one file (total ' num2str(length(iRelatedStudies)) ' files): ' 10 ...
                         '(in parentheses, the number of files for which the channel is bad)' 10 10 ...
                         strBad 10 10 ...
                         'The following channels will be considered as BAD for' 10 ...
                         'all the recordings and excluded from the source estimation:' 10 10], ...
                        'Exclude bad channels', [], sprintf('%d ', iBad));
                    if isCancel
                        continue;
                    elseif (~isempty(res) && isempty(str2num(res)))
                        errMessage = 'Invalid bad channel list of indices.';
                        continue;
                    end
                    % Get bad channels
                    BadChannels = 0 * BadChannels;
                    if ~isempty(res)
                        iBad = str2num(res);
                        BadChannels(iBad) = 1;
                    end
                % Return a warning message
                else
                    errMessage = [errMessage 'Bad channels for all the trials: ' sprintf('%d ', find(BadChannels)) 10];
                end
            end
            % Build a resulting ChannelFlag
            ChannelFlag = ones(length(ChannelMat.Channel), 1);
            ChannelFlag(BadChannels > 0) = -1;
            % No data loaded
            DataFile = [];
            Time = [];
        end
        
        % ===== CHANNEL FLAG =====
        % Get the list of good channels
        GoodChannel = good_channel(ChannelMat.Channel, ChannelFlag, OPTIONS.DataTypes);
        if isempty(GoodChannel)
            errMessage = [errMessage 'No good channels available.' 10];
            break;
        end
        
        % ===== LOAD NOISE COVARIANCE =====
        % Get channel study
        sStudyChannel = bst_get('Study', iStudyChannel);
        % Load NoiseCov file 
        NoiseCovMat = load(file_fullpath(sStudyChannel.NoiseCov(1).FileName));
        % Check for NaN values in the noise covariance
        if ~isempty(NoiseCovMat.NoiseCov) && (nnz(isnan(NoiseCovMat.NoiseCov(GoodChannel, GoodChannel))) > 0)
            errMessage = [errMessage 'The noise covariance contains NaN values. Please re-calculate it after tagging correctly the bad channels in the recordings.' 10];
            break;
        end
%         % Divide noise covariance by number of trials (DEPRECATED IN THIS VERSION)
%         if ~isempty(nAvg) && (nAvg > 1)
%             NoiseCovMat.NoiseCov = NoiseCovMat.NoiseCov ./ nAvg;
%         end
        
        % ===== LOAD DATA COVARIANCE =====
        % Load DataCov file 
        if (length(sStudyChannel.NoiseCov) >= 2) && ~isempty(sStudyChannel.NoiseCov(2).FileName)
            DataCovMat = load(file_fullpath(sStudyChannel.NoiseCov(2).FileName));
            % Check for NaN values in the noise covariance
            if ~isempty(DataCovMat.NoiseCov) && (nnz(isnan(DataCovMat.NoiseCov(GoodChannel, GoodChannel))) > 0)
                errMessage = [errMessage 'The data covariance contains NaN values. Please re-calculate it after tagging correctly the bad channels in the recordings.' 10];
                break;
            end
%             % Divide data covariance by number of trials
%             if isempty(nAvg) && (nAvg > 1)
%                 DataCovMat.NoiseCov = DataCovMat.NoiseCov ./ nAvg;
%             end
        else
            DataCovMat = [];
        end
        % Beamformers: Require a data covariance matrix
        if strcmpi(OPTIONS.InverseMethod, 'lcmv') && isempty(DataCovMat)
            errMessage = [errMessage 'You need to calculate a data covariance before using the "beamformer" option.' 10];
            break;
        end
        % Shrinkage: Require the FourthMoment matrix
        if strcmpi(OPTIONS.NoiseMethod, 'shrink') && ...
                ((~isempty(DataCovMat)  && (~isfield(DataCovMat, 'FourthMoment')  || isempty(DataCovMat.FourthMoment))) || ...
                 (~isempty(NoiseCovMat) && (~isfield(NoiseCovMat, 'FourthMoment') || isempty(NoiseCovMat.FourthMoment))))
            errMessage = [errMessage 'Please recalculate the noise and data covariance matrices for using the "automatic shrinkage" option.' 10];
            break;
        end
        
        % ===== LOAD HEAD MODEL =====
        bst_progress('text', 'Loading head model...');
        bst_progress('inc', 1);
        % Get headmodel file
        HeadModelFile = sStudyChannel.HeadModel(sStudyChannel.iHeadModel).FileName;
        % Load head model
        HeadModel = in_bst_headmodel(HeadModelFile, 0, 'Gain', 'GridLoc', 'GridOrient', 'GridAtlas', 'SurfaceFile', 'MEGMethod', 'EEGMethod', 'ECOGMethod', 'SEEGMethod', 'HeadModelType');
        % Apply current SSP projectors
        if ~isempty(ChannelMat.Projector)
            % Rebuild projector in the expanded form (I-UUt)
            Proj = process_ssp2('BuildProjector', ChannelMat.Projector, [1 2]);
            % Apply projectors
            if ~isempty(Proj)
                % Get all sensors for which the gain matrix was successfully computed
                iGainSensors = find(sum(isnan(HeadModel.Gain), 2) == 0);
                % Apply projectors to gain matrix
                HeadModel.Gain(iGainSensors,:) = Proj(iGainSensors,iGainSensors) * HeadModel.Gain(iGainSensors,:);
                % Apply SSPs on both sides of the noise covariance matrix
                NoiseCovMat.NoiseCov = Proj * NoiseCovMat.NoiseCov * Proj';
                if ~isempty(DataCovMat)
                    DataCovMat.NoiseCov = Proj * DataCovMat.NoiseCov * Proj';
                end
            end
        end
        % Select only good channels
        HeadModel.Gain = HeadModel.Gain(GoodChannel, :);
        % Apply average reference: separately SEEG, ECOG, EEG
        if any(ismember(unique({ChannelMat.Channel.Type}), {'EEG','ECOG','SEEG'}))
            % Create average reference montage
            sMontage = panel_montage('GetMontageAvgRef', [], ChannelMat.Channel(GoodChannel), ChannelFlag(GoodChannel), 0);
            HeadModel.Gain = sMontage.Matrix * HeadModel.Gain;
            % Apply average reference operator on both sides of the noise covariance matrix
            NoiseCovMat.NoiseCov(GoodChannel, GoodChannel) = sMontage.Matrix * NoiseCovMat.NoiseCov(GoodChannel, GoodChannel) * sMontage.Matrix';
            if ~isempty(DataCovMat)
                DataCovMat.NoiseCov(GoodChannel, GoodChannel) = sMontage.Matrix * DataCovMat.NoiseCov(GoodChannel, GoodChannel) * sMontage.Matrix';
            end
        end
        % Copy initial head model
        HeadModelInit = HeadModel;
        % Get number of sources
        nSources =  size(HeadModelInit.Gain,2) / 3;

        % ===== MIXED HEADMODEL =====
        if strcmpi(HeadModelInit.HeadModelType, 'mixed') && ~isempty(HeadModel.GridAtlas) && ~isempty(HeadModel.GridAtlas(1).Scouts)
            % Only supported for wMNE
            if ~ismember(OPTIONS.InverseMethod, {'minnorm', 'gls', 'lcmv'})
                errMessage = [errMessage 'The mixed headmodel is currently only supported for the following inverse solutions: Minimum norm, dipole fitting, beamformer.' 10];
                break;
            end
            % Initialize variable
            HeadModel.Gain      = [];
            HeadModel.GridAtlas = [];
            HeadModel           = repmat(HeadModel, 1, length(HeadModelInit.GridAtlas(1).Scouts));
            iVert2Grid = [];
            iAllGrid   = [];
            iAllSource = [];
            iOffset    = 0;
            % Split the head model in multiple entries
            for iScout = 1:length(HeadModelInit.GridAtlas(1).Scouts)
                % Get indices in the Gain matrix
                sScout = HeadModelInit.GridAtlas(1).Scouts(iScout);
                iGainRows = sort([3*sScout.GridRows-2, 3*sScout.GridRows-1, 3*sScout.GridRows]);
                % Create the headmodel structure for the current region
                HeadModel(iScout).Gain       = HeadModelInit.Gain(:, iGainRows);
                HeadModel(iScout).GridLoc    = HeadModelInit.GridLoc(sScout.GridRows, :);
                HeadModel(iScout).GridOrient = HeadModelInit.GridOrient(sScout.GridRows, :);
                switch (sScout.Region(3))
                    case 'C',  OPTIONS.SourceOrient{iScout} = 'fixed';  nComp = 1;
                    case 'U',  OPTIONS.SourceOrient{iScout} = 'free';   nComp = 3;
                    case 'L',  OPTIONS.SourceOrient{iScout} = 'loose';  nComp = 3;
                end
                % In the case of a surface region, add the match of the vertices in the cortex surface and the GridLoc matrix
                if strcmpi(sScout.Region(2), 'S')
                    iVert2Grid = [iVert2Grid; sScout.Vertices', sScout.GridRows'];
                end
                % Add to the scout definition the indices in the ImageGrid
                iAllGrid   = [iAllGrid,   reshape(repmat(sScout.GridRows,nComp,1), 1, [])];
                iAllSource = [iAllSource, iOffset + (1:nComp*length(sScout.GridRows))];
                iOffset = iOffset + nComp*length(sScout.GridRows);
            end
            % Create sparse conversion matrices between indices
            if ~isempty(iVert2Grid)
                HeadModelInit.GridAtlas(1).Vert2Grid = logical(sparse(iVert2Grid(:,2), iVert2Grid(:,1), ones(size(iVert2Grid,1),1)));
            else
                HeadModelInit.GridAtlas(1).Vert2Grid = [];
            end
            if ~isempty(iAllSource)
                HeadModelInit.GridAtlas(1).Grid2Source = logical(sparse(iAllSource, iAllGrid, ones(size(iAllSource))));
            else
                HeadModelInit.GridAtlas(1).Grid2Source = [];
            end
        end


        %% ===== COMPUTE INVERSE SOLUTION =====
        bst_progress('text', 'Estimating sources...');
        bst_progress('inc', 1);
        % NoiseCov: keep only the good channels
        OPTIONS.NoiseCovMat = NoiseCovMat;
        OPTIONS.NoiseCovMat.NoiseCov = OPTIONS.NoiseCovMat.NoiseCov(GoodChannel, GoodChannel);
        if isfield(OPTIONS.NoiseCovMat, 'FourthMoment') && ~isempty(OPTIONS.NoiseCovMat.FourthMoment)
            OPTIONS.NoiseCovMat.FourthMoment = OPTIONS.NoiseCovMat.FourthMoment(GoodChannel, GoodChannel);
        end
        if isfield(OPTIONS.NoiseCovMat, 'nSamples') && ~isempty(OPTIONS.NoiseCovMat.nSamples)
            OPTIONS.NoiseCovMat.nSamples = OPTIONS.NoiseCovMat.nSamples(GoodChannel, GoodChannel);
        end
        % DataCov: keep only the good channels
        if ~isempty(DataCovMat)
            OPTIONS.DataCovMat = DataCovMat;
            OPTIONS.DataCovMat.NoiseCov     = OPTIONS.DataCovMat.NoiseCov(GoodChannel, GoodChannel);
            OPTIONS.DataCovMat.FourthMoment = OPTIONS.DataCovMat.FourthMoment(GoodChannel, GoodChannel);
            OPTIONS.DataCovMat.nSamples     = OPTIONS.DataCovMat.nSamples(GoodChannel, GoodChannel);
        end
        % Get channels types
        OPTIONS.ChannelTypes = {ChannelMat.Channel(GoodChannel).Type};
        % Switch depending on the selected inverse method
        switch( OPTIONS.InverseMethod )       
            case {'minnorm', 'gls', 'lcmv'}
                % Call John's wmne function
                % NOTE: The output HeadModel param is used here in return to save LOTS of memory in the bst_inverse_linear_2018 function,
                %       event if it seems to be absolutely useless. Having a parameter in both input and output have the
                %       effect in Matlab of passing them "by reference".
                try
                    [Results, OPTIONS] = bst_inverse_linear_2018(HeadModel, OPTIONS);
                catch e
                    if bst_get('MatlabVersion') == 904
                        errMsg = ['Note: Matlab 2018a changed the behavior of the SVD() function. ' ...
                            10 'If issues arise, we recommend using another version.'];
                        e = MException(e.identifier, [e.message 10 10 errMsg]);
                        throw(e);
                    else
                        rethrow(e);
                    end
                end
            case 'mem'
                % Add options needed by the MEM functions
                OPTIONS.DataFile      = DataFile;
                OPTIONS.DataTime      = Time;
                OPTIONS.Channel       = ChannelMat.Channel(GoodChannel);
                OPTIONS.Data          = DataMat.F(GoodChannel,:);
                OPTIONS.ChannelFlag   = ChannelFlag(GoodChannel);
                OPTIONS.ResultFile    = [];
                OPTIONS.HeadModelFile = HeadModelFile;
                OPTIONS.GoodChannel   = GoodChannel;
                OPTIONS.FunctionName  = 'mem';
                % Call the mem solver
                [Results, OPTIONS] = be_main(HeadModel, OPTIONS);
                Results.nComponents = round(max(size(Results.ImageGridAmp,1),size(Results.ImagingKernel,1)) / nSources);
                % Get outputs
                DataFile = OPTIONS.DataFile; 
                Time     = OPTIONS.DataTime;
            otherwise
                error('Unknown method');
        end
        % Error handling
        if isempty(Results)
            errMessage = [errMessage 'The inverse function returned an empty structure.' 10];
            break;
        end
        % Copy outputs to a standard results structure
        ResultsMat = db_template('resultsmat');
        ResultsMat = struct_copy_fields(ResultsMat, Results, 1);
        
        % ===== COMPUTE FULL RESULTS =====
        % Full results
        if (OPTIONS.ComputeKernel == 0) && ~isempty(ResultsMat.ImagingKernel) && ~isempty(DataFile)
            % Load data
            DataMat = in_bst_data(DataFile, 'F');
            % Incompatible options: Full results + raw files (impossible to view after)
            if isstruct(DataMat.F)
                errMessage = [errMessage 'Cannot compute full results for raw files: import the files first or compute an inversion kernel only.' 10];
                break;
            end
            % Multiply inversion kernel with the recordings
            ResultsMat.ImageGridAmp = ResultsMat.ImagingKernel * DataMat.F(GoodChannel, :);
            ResultsMat.ImagingKernel = [];
        end
        % If kernel only on raw data: do not save the Time vector
        if ~isempty(ResultsMat.ImagingKernel) && ~isShared && isRaw
            Time = [];
        % Check if no time dimension
        elseif ~isempty(ResultsMat.ImageGridAmp) && (size(ResultsMat.ImageGridAmp, 2) == 1)
            % If the output is not a timecourse: replicate the results to get two time instants
            ResultsMat.ImageGridAmp = repmat(ResultsMat.ImageGridAmp, [1,2]); 
            % Keep only the first and last time instants
            Time = [Time(1), Time(end)];
        end
        
        
        %% ===== SAVE RESULTS FILE =====
        bst_progress('text', 'Saving results...');
        bst_progress('inc', 1);
        % ===== OUTPUT FILENAME =====
        % Add method name
        strMethod = methodTag;
        % Add modality
        for i = 1:length(OPTIONS.DataTypes)
            strMethod = [strMethod, '_', file_standardize(OPTIONS.DataTypes{i})];
        end
        % Add kernel tag
        if OPTIONS.ComputeKernel
            strMethod = [strMethod, '_KERNEL'];
        end
        % Output folder
        if isempty(DataFile)
            OutputDir = bst_fileparts(file_fullpath(ChannelFile));
        else
            OutputDir = bst_fileparts(file_fullpath(DataFile));
        end
        % Output filename
        ResultFile = bst_process('GetNewFilename', OutputDir, ['results_', strMethod]);

        % ===== CREATE FILE STRUCTURE =====
        ResultsMat.Comment       = [OPTIONS.Comment ' 2018'];
        ResultsMat.Function      = OPTIONS.FunctionName;
        ResultsMat.Time          = Time;
        ResultsMat.DataFile      = DataFile;
        ResultsMat.HeadModelFile = HeadModelFile;
        ResultsMat.HeadModelType = HeadModelInit.HeadModelType;
        ResultsMat.ChannelFlag   = ChannelFlag;
        ResultsMat.GoodChannel   = GoodChannel;
        ResultsMat.SurfaceFile   = file_short(HeadModelInit.SurfaceFile);        
        switch lower(ResultsMat.HeadModelType)
            case 'volume'
                ResultsMat.GridLoc    = HeadModelInit.GridLoc;
                % ResultsMat.GridOrient = [];
            case 'surface'
                ResultsMat.GridLoc    = [];
                % ResultsMat.GridOrient = [];    % THE ORIENTATION CAN BE RETURNED BY THE INVERSE METHOD ('optim')
            case 'mixed'
                ResultsMat.GridLoc    = HeadModelInit.GridLoc;
                ResultsMat.GridOrient = HeadModelInit.GridOrient;
        end
        ResultsMat.GridAtlas = HeadModelInit.GridAtlas;
        ResultsMat.nAvg      = nAvg;
        ResultsMat.Options   = OPTIONS;
        % History
        ResultsMat = bst_history('add', ResultsMat, 'compute', ['Source estimation: ' OPTIONS.InverseMethod]);
        % Make file comment unique
        if ~isempty(sStudy.Result)
            ResultsMat.Comment = file_unique(ResultsMat.Comment, {sStudy.Result.Comment});
        end
        % Save new file structure
        bst_save(ResultFile, ResultsMat, 'v6');

        % ===== REGISTER NEW FILE =====
        % Create new results structure
        newResult = db_template('results');
        newResult.Comment       = ResultsMat.Comment;
        newResult.FileName      = file_short(ResultFile);
        newResult.DataFile      = DataFile;
        newResult.isLink        = 0;
        newResult.HeadModelType = ResultsMat.HeadModelType;
        % Add new entry to the database
        iResult = length(sStudy.Result) + 1;
        sStudy.Result(iResult) = newResult;
        % Update Brainstorm database
        bst_set('Study', iStudy, sStudy);
        
        % ===== UPDATE DISPLAY =====
        % Update tree
        panel_protocols('UpdateNode', 'Study', iStudy);
        % Update links
        if isShared
            if isDefaultStudy
                % If added to a 'default_study' node: need to update results links 
                OutputLinks = db_links('Subject', sStudy.BrainStormSubject);
                % Update whole tree display
                panel_protocols('UpdateTree');
            else
                % Update links to the new results file 
                OutputLinks = db_links('Study', iStudy);
                % Update display of the study node
                panel_protocols('UpdateNode', 'Study', iStudy);
            end
            % Find in the links the ones that are based on the node that was just calculated
            isNewLink = ~cellfun(@(c)isempty(strfind(c, newResult.FileName)), OutputLinks);
            OutputFiles = cat(2, OutputFiles, OutputLinks(isNewLink));
        else
            % Store output filename
            OutputFiles{end+1} = newResult.FileName;
        end
        % Expand data node
        panel_protocols('SelectNode', [], newResult.FileName);
    end
    % Save database
    db_save();
    % Hide progress bar
    bst_progress('stop');
end



%% ===== GET MODALITY COMMENT =====
function Comment = GetModalityComment(Modalities)
    % Replace "MEG GRAD+MEG MAG" with "MEG ALL"
    if all(ismember({'MEG GRAD', 'MEG MAG'}, Modalities))
        Modalities = setdiff(Modalities, {'MEG GRAD', 'MEG MAG'});
        Modalities{end+1} = 'MEG ALL';
    end
    % Loop to build comment
    Comment = '';
    for im = 1:length(Modalities)
        if (im >= 2)
            Comment = [Comment, '+'];
        end
        Comment = [Comment, Modalities{im}];
    end    
end




