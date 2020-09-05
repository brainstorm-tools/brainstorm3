function varargout = process_inverse( varargin )
% PROCESS_INVERSE: Compute an inverse model.

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
% Authors: Francois Tadel, 2012-2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % ===== PROCESS =====
    % Description the process
    sProcess.Comment     = 'Compute sources [2009]';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Sources';
    sProcess.Index       = 325;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/SourceEstimation';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'results', 'results'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Options: Comment
    sProcess.options.Comment.Comment = 'Comment: ';
    sProcess.options.Comment.Type    = 'text';
    sProcess.options.Comment.Value   = '';
    % Option: Inverse method
    sProcess.options.method.Comment = {'Minimum norm estimates (wMNE)', 'dSPM', 'sLORETA'};
    sProcess.options.method.Type    = 'radio';
    sProcess.options.method.Value   = 1;
    % Options: MNE options
    sProcess.options.wmne.Comment = {'panel_wmne', 'Source estimation options: '};
    sProcess.options.wmne.Type    = 'editpref';
    sProcess.options.wmne.Value   = bst_wmne();
    % Option: Sensors selection
    sProcess.options.sensortypes.Comment = 'Sensor types:&nbsp;&nbsp;&nbsp;&nbsp;';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, MEG MAG, MEG GRAD, EEG';
    % Option: Output
    sProcess.options.sep3.Type      = 'separator';
    sProcess.options.output.Comment = {'Kernel only: shared', 'Kernel only: one per file', 'Full results: one per file'};
    sProcess.options.output.Type    = 'radio';
    sProcess.options.output.Value   = 1;
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
    % MNE options
    OPTIONS = struct_copy_fields(OPTIONS, sProcess.options.wmne.Value, 1);
    % Get options
    switch (sProcess.options.method.Value)
        case 1,  OPTIONS.InverseMethod = 'wmne';
        case 2,  OPTIONS.InverseMethod = 'dspm';
        case 3,  OPTIONS.InverseMethod = 'sloreta';
    end
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
    % Get modalities in channel files
    AllSensorTypes = unique(cat(2, sInputs.ChannelTypes));
    AllSensorTypes = intersect(AllSensorTypes, {'MEG MAG', 'MEG GRAD', 'MEG', 'EEG', 'ECOG', 'SEEG'});
    if any(ismember(AllSensorTypes, {'MEG MAG', 'MEG GRAD'}))
        AllSensorTypes = setdiff(AllSensorTypes, 'MEG');
    end
    % Get valid modalities in head models
    allChanFiles = unique({sInputs.ChannelFile});
    for i = 1:length(allChanFiles)
        % Get study
        sStudy = bst_get('ChannelFile', allChanFiles{i});
        % Check if all the files exist
        if isempty(sStudy.Channel) || isempty(sStudy.HeadModel) || isempty(sStudy.iHeadModel) || isempty(sStudy.NoiseCov) || isempty(sStudy.NoiseCov(1).FileName)
            bst_report('Error', sProcess, [], 'No channel file, noise covariance, or headmodel or for at least one of the files.');
            return;
        end
        % Remove all the modalities that do not exist in the headmodels
        if isempty(sStudy.HeadModel(sStudy.iHeadModel).MEGMethod)
            AllSensorTypes = setdiff(AllSensorTypes, {'MEG', 'MEG MAG', 'MEG GRAD'});
        end
        if isempty(sStudy.HeadModel(sStudy.iHeadModel).EEGMethod)
            AllSensorTypes = setdiff(AllSensorTypes, {'EEG'});
         end
        if isempty(sStudy.HeadModel(sStudy.iHeadModel).ECOGMethod)
            AllSensorTypes = setdiff(AllSensorTypes, {'ECOG'});
        end
        if isempty(sStudy.HeadModel(sStudy.iHeadModel).SEEGMethod)
            AllSensorTypes = setdiff(AllSensorTypes, {'SEEG'});
        end
    end
    % Selected sensor types
    OPTIONS.DataTypes = strtrim(str_split(sProcess.options.sensortypes.Value, ',;'));
    if ismember('MEG', OPTIONS.DataTypes) && any(ismember({'MEG GRAD','MEG MAG'}, AllSensorTypes))
        OPTIONS.DataTypes = union(setdiff(OPTIONS.DataTypes, 'MEG'), {'MEG MAG', 'MEG GRAD'});
    end
    OPTIONS.DataTypes = intersect(OPTIONS.DataTypes, AllSensorTypes);
    if isempty(OPTIONS.DataTypes)
        strTypes = '';
        for i = 1:length(AllSensorTypes)
            if (i > 1)
                strTypes = [strTypes, ', '];
            end
            strTypes = [strTypes, AllSensorTypes{i}];
        end
        bst_report('Error', sProcess, [], ['No valid sensor type selected.' 10 'Valid options are: ' strTypes]);
        return;
    end
    % Comment
    if isfield(sProcess.options, 'Comment') && isfield(sProcess.options.Comment, 'Value') && ~isempty(sProcess.options.Comment.Value)
        OPTIONS.Comment = sProcess.options.Comment.Value;
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
%          Francois Tadel, 2009-2014
%
function [OutputFiles, errMessage] = Compute(iStudies, iDatas, OPTIONS)
    % Initialize returned variables
    OutputFiles = {};
    errMessage = [];
    % Default options settings
    Def_OPTIONS = struct(...
        'InverseMethod',       'wmne', ... % A string that specifies the imaging method: wmne, dspm, sloreta, ...
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
        % Check noise covariance
        if isempty(sChanStudies(i).NoiseCov) || isempty(sChanStudies(i).NoiseCov(1).FileName)
            errMessage = 'No noise covariance matrix available.';
            return;
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
        sMethod = gui_show_dialog('Compute sources', @panel_inverse, 1, [], AllMod, isShared, HeadModelType);
        if isempty(sMethod)
            return;
        end
        % Override default options
        OPTIONS = struct_copy_fields(OPTIONS, sMethod, 1);
        % Get mthod options
        switch (OPTIONS.InverseMethod)
            % === MINIMUM NORM ===
            case {'wmne','dspm','sloreta','gls','glsr','mnej','gls_p','glsr_p','mnej_p'}
                % Default options
                MethodOptions = bst_wmne();
                MethodOptions.InverseMethod = OPTIONS.InverseMethod;
                % DBA: Do not select the orientation constrain here
                if strcmpi(HeadModelType, 'mixed')
                    MethodOptions.SourceOrient = [];
                    MethodOptions.flagSourceOrient = [0 0 0 0];
                    OPTIONS.SourceOrient = [];
                % Regular definition of the orientation constrain
                else
                    % Remove radial sources in MEG with spherical headmodels ?
                    RemoveSilentComp = any(ismember(AllMod, {'MEG GRAD', 'MEG MAG', 'MEG'})) && strcmpi(MEGMethod, 'meg_sphere');
                    % sLORETA and spherical models: Truncated source model must be the default
                    if RemoveSilentComp && strcmpi(OPTIONS.InverseMethod, 'sloreta')
                        MethodOptions.flagSourceOrient = [1 0 0 2];
                    % Else: All source models available
                    else
                        MethodOptions.flagSourceOrient = [1 1 1 RemoveSilentComp];
                    end
                    % Default source model
                    switch lower(MethodOptions.SourceOrient{1})
                        case 'fixed',  MethodOptions.flagSourceOrient(1) = 2;
                        case 'loose',  MethodOptions.flagSourceOrient(2) = 2;
                        case 'free',   MethodOptions.flagSourceOrient(3) = 2;
                    end
                    % Default options are different depending on the head model type
                    switch (HeadModelType)
                        case {'surface', 'ImageGrid'}
                            MethodOptions.SourceOrient{1} = 'fixed';
                        case 'volume'
                            MethodOptions.SourceOrient{1} = 'free';
                            MethodOptions.flagSourceOrient = [0 0 2 0];
                    end
                end
                % For sLORETA: no depth weighting
                if strcmpi(OPTIONS.InverseMethod, 'sloreta')
                    MethodOptions.depth = 0;
                end
                % Interface to edit options
                if bst_get('ExpertMode')
                    MethodOptions = gui_show_dialog('Minimum norm options', @panel_wmne, 1, [], MethodOptions, OPTIONS.DataTypes);
                end

            % === BRAINENTROPY MEM ===
            case 'mem'
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
        end
        % Canceled by user
        if isempty(MethodOptions)
            return
        end
        % Add options to list
        OPTIONS = struct_copy_fields(OPTIONS, MethodOptions, 1);
    end
    % If no MEG and no EEG selected
    if isempty(OPTIONS.DataTypes)
        errMessage = 'Please select at least one modality.';
        return;
    end
    % Tags corresponding to the different methods
    switch(OPTIONS.InverseMethod)
        case 'wmne',    methodTag = 'MN';
        case 'gls',     methodTag = 'GLS';
        case 'gls_p',   methodTag = 'GLSP';
        case 'glsr',    methodTag = 'GLSR';
        case 'glsr_p',  methodTag = 'GLSRP';
        case 'mnej',    methodTag = 'MNEJ';
        case 'mnej_p',  methodTag = 'MNEJP';
        case 'dspm',    methodTag = 'dSPM';
        case 'sloreta', methodTag = 'sLORETA';
        case 'mem',     methodTag = 'MEM';
    end

    %% ===== COMMENT =====
    % Base comment: "METHOD: MODALITIES"
    if isempty(OPTIONS.Comment)
        OPTIONS.Comment = [methodTag, ': ' GetModalityComment(OPTIONS.DataTypes)];
    end
    % Add source orientation option string
    strOptions = '';
    if isempty(OPTIONS.SourceOrient)
        strOptions = 'Mixed';
    elseif any(strcmpi(OPTIONS.InverseMethod, {'wmne','dspm','sloreta','gls','glsr','mnej'}))
        switch (OPTIONS.SourceOrient{1})
            case 'fixed',      strOptions = 'Constr';
            case 'loose',      strOptions = 'Loose';
            case 'free',       strOptions = 'Unconstr';
            case 'truncated',  strOptions = 'Trunc';
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
            % Load data file info
            if OPTIONS.ComputeKernel
                DataMat = in_bst_data(DataFile, 'ChannelFlag', 'Time', 'nAvg');
            else
                DataMat = in_bst_data(DataFile, 'ChannelFlag', 'Time', 'nAvg', 'F');
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
                % Channel number
                if isempty(nChannels)
                    nChannels = length(DataMat.ChannelFlag);
                elseif (nChannels ~= length(DataMat.ChannelFlag))
                    errMessage = 'All data files must have the same number of channels.';
                    continue;
                end
                % Count number of times the channe is bad
                if isempty(BadChannels)
                    BadChannels = double(DataMat.ChannelFlag < 0);
                else
                    BadChannels = BadChannels + (DataMat.ChannelFlag < 0);
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
        NoiseCovMat = load(file_fullpath(sStudyChannel.NoiseCov(1).FileName), 'NoiseCov');
        NoiseCov = NoiseCovMat.NoiseCov;
        % Check for NaN values in the noise covariance
        if ~isempty(NoiseCov) && (nnz(isnan(NoiseCov(GoodChannel, GoodChannel))) > 0)
            errMessage = [errMessage 'The noise covariance contains NaN values. Please re-calculate it after tagging correctly the bad channels in the recordings.' 10];
            break;
        end
        % Divide noise covariance by number of trials
        if ~isempty(nAvg) && (nAvg > 1)
            NoiseCov = NoiseCov ./ nAvg;
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
                NoiseCov = Proj * NoiseCov * Proj';
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
            NoiseCov(GoodChannel, GoodChannel) = sMontage.Matrix * NoiseCov(GoodChannel, GoodChannel) * sMontage.Matrix';
        end
        % Copy initial head model
        HeadModelInit = HeadModel;
        % Get number of sources
        nSources =  size(HeadModelInit.Gain,2) / 3;
        % Check that processing MEG with a spherical headmodel: if not, discard the 'truncated' option
        if isfield(OPTIONS, 'SourceOrient') && ~isempty(OPTIONS.SourceOrient) && strcmpi(OPTIONS.SourceOrient{1}, 'truncated')  && (~isfield(HeadModel, 'MEGMethod') || ~strcmpi(HeadModel.MEGMethod, 'meg_sphere'))
            disp('BST> Recordings do not contain MEG, or forward model is not spherical: ignore "truncated" source orientation.');
            OPTIONS.SourceOrient = {'loose'};
        end

        % ===== MIXED HEADMODEL =====
        if strcmpi(HeadModelInit.HeadModelType, 'mixed') && ~isempty(HeadModel.GridAtlas) && ~isempty(HeadModel.GridAtlas(1).Scouts)
            % Only supported for wMNE
            if ~ismember(OPTIONS.InverseMethod, {'wmne', 'dspm', 'sloreta'})
                errMessage = [errMessage 'The mixed headmodel is currently only supported for the wMNE/dSPM/sLORETA inverse solution.' 10];
                break;
            end
            % Split head model into multiple blocks with different properties
            [HeadModel, HeadModelInit, OPTIONS.SourceOrient] = SplitHeadModel(HeadModelInit);
            % Fix the comment of the file
            OPTIONS.Comment = strrep(OPTIONS.Comment, 'Constr',   'Mixed');
            OPTIONS.Comment = strrep(OPTIONS.Comment, 'Loose',    'Mixed');
            OPTIONS.Comment = strrep(OPTIONS.Comment, 'Unconstr', 'Mixed');
        end


        %% ===== COMPUTE INVERSE SOLUTION =====
        bst_progress('text', 'Estimating sources...');
        bst_progress('inc', 1);
        % NoiseCov: keep only the good channels
        OPTIONS.NoiseCov = NoiseCov(GoodChannel, GoodChannel);
        % Get channels types
        OPTIONS.ChannelTypes = {ChannelMat.Channel(GoodChannel).Type};
        % Switch depending on the selected inverse method
        switch( OPTIONS.InverseMethod )       
            case {'wmne', 'dspm', 'sloreta'}
                % Call Rey's wmne function
                % NOTE: The output HeadModel param is used here in return to save LOTS of memory in the bst_wmne function,
                %       event if it seems to be absolutely useless. Having a parameter in both input and output have the
                %       effect in Matlab of passing them "by reference".
                [Results, OPTIONS] = bst_wmne(HeadModel, OPTIONS);
            case {'gls', 'gls_p', 'glsr', 'glsr_p', 'mnej', 'mnej_p'}
                % Mosher's function
                [Results, OPTIONS] = bst_wmne_mosher(HeadModel, OPTIONS);
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
                OPTIONS.NoiseCovRaw   = NoiseCov;
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
        ResultsMat.Comment       = OPTIONS.Comment;
        ResultsMat.Function      = OPTIONS.InverseMethod;
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
                ResultsMat.GridOrient = [];
            case 'surface'
                ResultsMat.GridLoc    = [];
                ResultsMat.GridOrient = [];
            case 'mixed'
                ResultsMat.GridLoc    = HeadModelInit.GridLoc;
                ResultsMat.GridOrient = HeadModelInit.GridOrient;
        end
        ResultsMat.GridAtlas = HeadModelInit.GridAtlas;
        ResultsMat.nAvg      = nAvg;
        ResultsMat.Options   = OPTIONS;
        % History
        ResultsMat = bst_history('add', ResultsMat, 'compute', ['Source estimation: ' OPTIONS.InverseMethod]);
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


%% ===== SPLIT MIXED HEADMODEL =====
% Split head model into multiple blocks with different properties
function [HeadModel, HeadModelInit, SourceOrient] = SplitHeadModel(HeadModelInit)
    % Initialize variables
    HeadModel.Gain      = [];
    HeadModel.GridAtlas = [];
    HeadModel           = repmat(HeadModel, 1, length(HeadModelInit.GridAtlas(1).Scouts));
    SourceOrient = {};
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
            case 'C',  SourceOrient{iScout} = 'fixed';  nComp = 1;
            case 'U',  SourceOrient{iScout} = 'free';   nComp = 3;
            case 'L',  SourceOrient{iScout} = 'loose';  nComp = 3;
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

