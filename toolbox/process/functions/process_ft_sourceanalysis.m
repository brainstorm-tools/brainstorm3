function varargout = process_ft_sourceanalysis( varargin )
% PROCESS_FT_SOURCEANALYSIS Call FieldTrip function ft_sourceanalysis

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
% Authors: Francois Tadel, 2016-2017

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % ===== PROCESS =====
    % Description the process
    sProcess.Comment     = 'FieldTrip: ft_sourceanalysis';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Sources';
    sProcess.Index       = 356;
    sProcess.Description = 'http://www.fieldtriptoolbox.org/tutorial/minimumnormestimate';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Label: Warning
    sProcess.options.label1.Comment = '<B>Warning</B>: Process under development.<BR><BR>';
    sProcess.options.label1.Type    = 'label';
    % Option: Inverse method
    sProcess.options.method.Comment = 'Inverse method:';
    sProcess.options.method.Type    = 'combobox_label';
    sProcess.options.method.Value   = {'mne', {'LCMV beamformer', 'SAM beamformer', 'DICS beamformer', 'MNE', 'sLORETA', 'eLORETA', 'MUSIC', 'PCC', 'Residual variance'; ...
                                               'lcmv',            'sam',            'dics',            'mne', 'sloreta', 'eloreta', 'music', 'pcc', 'rv'}};
    % Option: Sensors selection
    sProcess.options.sensortype.Comment = 'Sensor type:';
    sProcess.options.sensortype.Type    = 'combobox_label';
    sProcess.options.sensortype.Value   = {'MEG', {'MEG', 'MEG GRAD', 'MEG MAG', 'EEG', 'SEEG', 'ECOG'; ...
                                                   'MEG', 'MEG GRAD', 'MEG MAG', 'EEG', 'SEEG', 'ECOG'}};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % Initialize fieldtrip
    bst_ft_init();
    
    % ===== GET OPTIONS =====
    % Inverse options
    Method   = sProcess.options.method.Value{1};
    Modality = sProcess.options.sensortype.Value{1};
    % Get unique channel files 
    AllChannelFiles = unique({sInputs.ChannelFile});
    % Progress bar
    bst_progress('start', 'ft_sourceanalysis', 'Loading input files...', 0, 2*length(sInputs));
   
    % ===== LOOP ON FOLDERS =====
    for iChanFile = 1:length(AllChannelFiles)
        bst_progress('text', 'Loading input files...');
        % Get the study
        [sStudyChan, iStudyChan] = bst_get('ChannelFile', AllChannelFiles{iChanFile});
        % Error if there is no head model available
        if isempty(sStudyChan.iHeadModel)
            bst_report('Error', sProcess, [], ['No head model available in folder: ' bst_fileparts(sStudyChan.FileName)]);
            continue;
        elseif isempty(sStudyChan.NoiseCov) || isempty(sStudyChan.NoiseCov(1).FileName)
            bst_report('Error', sProcess, [], ['No noise covariance matrix available in folder: ' bst_fileparts(sStudyChan.FileName)]);
            continue;
        end
        % Load channel file
        ChannelMat = in_bst_channel(AllChannelFiles{iChanFile});
        % Get selected sensors
        iChannels = channel_find(ChannelMat.Channel, Modality);
        if isempty(iChannels)
            bst_report('Error', sProcess, sInput, ['Channels "' Modality '" not found in channel file.']);
            return;
        end
        % Load head model
        HeadModelFile = sStudyChan.HeadModel(sStudyChan.iHeadModel).FileName;
        HeadModelMat = in_bst_headmodel(HeadModelFile);
        % Load data covariance matrix
        NoiseCovFile = sStudyChan.NoiseCov(1).FileName;
        NoiseCovMat = load(file_fullpath(NoiseCovFile));
%%% DATA OR NOISE COVARIANCE ????

        % ===== LOOP ON DATA FILES =====
        % Get data files for this channel file
        iChanInputs = find(ismember({sInputs.ChannelFile}, AllChannelFiles{iChanFile}));
        % Loop on data files
        for iInput = 1:length(iChanInputs)
            
            % === LOAD DATA ===
            % Load data
            DataFile = sInputs(iChanInputs(iInput)).FileName;
            DataMat = in_bst_data(DataFile);
            iStudyData = sInputs(iChanInputs(iInput)).iStudy;
            % Remove bad channels
            iBadChan = find(DataMat.ChannelFlag == -1);
            iChannelsData = setdiff(iChannels, iBadChan);
            % Error: All channels tagged as bad
            if isempty(iChannelsData)
                bst_report('Error', sProcess, sInput, 'All the selected channels are tagged as bad.');
                return;
            end
            % Convert data file to FieldTrip format
            ftData = out_fieldtrip_data(DataMat, ChannelMat, iChannelsData, 1);
            % Add data covariance
            ftData.cov = NoiseCovMat.NoiseCov(iChannelsData,iChannelsData);
            % Convert head model to FieldTrip format
            [ftHeadmodel, ftLeadfield] = out_fieldtrip_headmodel(HeadModelMat, ChannelMat, iChannelsData, 1);

            % === CALLING FIELDTRIP FUNCTION ===
            bst_progress('text', 'Calling FieldTrip function: ft_sourceanalysis...');
            % Prepare FieldTrip cfg structure
            cfg           = [];
            cfg.method    = Method;
            cfg.grid      = ftLeadfield;
            cfg.headmodel = ftHeadmodel;
            % Additional options for the method
            switch (Method)
                case 'mne'
                    cfg.mne.prewhiten = 'yes';
                    cfg.mne.lambda    = 3;
                    cfg.mne.scalesourcecov = 'yes';
                    Time = DataMat.Time;
                    
                case 'lcmv'
                    Time = [DataMat.Time(1), DataMat.Time(2)];
                    
                case 'dics'
                    % EXAMPLE 1
                    % cfg                = [];
                    % cfg.grid           = grid;
                    % cfg.frequency      = 10;
                    % cfg.vol            = hdm;
                    % cfg.gradfile       = 'grad.mat';
                    % cfg.projectnoise   = 'yes';
                    % cfg.keeptrials     = 'no';
                    % cfg.keepfilter     = 'yes';
                    % cfg.keepcsd        = 'yes';
                    % cfg.keepmom        = 'yes';
                    % cfg.lambda         = 0.1 * mean(f.powspctrm(:,nearest(cfg.frequency)),1);
                    % cfg.method         = 'dics';
                    % cfg.feedback       = 'textbar';
                    % source             = ft_sourceanalysis(cfg,f);
                    
                    % EXAMPLE 2
                    % % freqanalysis %
                    % cfg=[];
                    % cfg.method      = 'mtmfft';
                    % cfg.output      = 'powandcsd';  % gives power and cross-spectral density matrices
                    % cfg.foilim      = [60 60];      % analyse 40-80 Hz (60 Hz +/- 20 Hz smoothing)
                    % cfg.taper       = 'dpss';
                    % cfg.tapsmofrq   = 20;
                    % cfg.keeptrials  = 'yes';        % in order to separate the conditions again afterwards, we need to keep the trials. This is not otherwise necessary to compute the common filter
                    % cfg.keeptapers  = 'no';
                    % 
                    % freq = ft_freqanalysis(cfg, data);
                    % 
                    % % compute common spatial filter %
                    % cfg=[];
                    % cfg.method      = 'dics';
                    % cfg.grid        = grid;         % previously computed grid
                    % cfg.headmodel   = vol;          % previously computed volume conduction model
                    % cfg.frequency   = 60;
                    % cfg.dics.keepfilter  = 'yes';        % remember the filter
                    % 
                    % source = ft_sourceanalysis(cfg, freq);

                case 'pcc'
                    % % ft_freqanalysis %
                    % cfg=[];
                    % cfg.method      = 'mtmfft';
                    % cfg.output      = 'fourier';  % gives the complex Fourier spectra
                    % cfg.foilim      = [60 60];    % analyse 40-80 Hz (60 Hz +/- 20 Hz smoothing)
                    % cfg.taper       = 'dpss';
                    % cfg.tapsmofrq   = 20;
                    % cfg.keeptrials  = 'yes';      % in order to separate the conditions again afterwards, we need to keep the trials. This is not otherwise necessary to compute the common filter
                    % cfg.keeptapers  = 'yes';
                    % freq = ft_freqanalysis(cfg, data);
                    % 
                    % % compute common spatial filter AND project all trials through it %
                    % cfg=[]; 
                    % cfg.method      = 'pcc';
                    % cfg.grid        = grid;       % previously computed grid
                    % cfg.headmodel   = vol;        % previously computed volume conduction model
                    % cfg.frequency   = 60;
                    % cfg.keeptrials  = 'yes';      % keep single trials. Only necessary if you are interested in reconstructing single trial data
                    % source = ft_sourceanalysis(cfg, freq); 
            end
            % Call FieldTrip function
            ftSource = ft_sourceanalysis(cfg, ftData);

            % === CREATE OUTPUT STRUCTURE ===
            bst_progress('text', 'Saving source file...');
            bst_progress('inc', 1);
            % Create structure
            ResultsMat = db_template('resultsmat');
            ResultsMat.ImagingKernel = [];
            ResultsMat.ImageGridAmp  = sqrt(ftSource.avg.pow);
            ResultsMat.nComponents   = 1;
            ResultsMat.Comment       = ['ft_sourceanalysis: ' Method];
            ResultsMat.Function      = Method;
            ResultsMat.Time          = Time;
            ResultsMat.DataFile      = DataFile;
            ResultsMat.HeadModelFile = HeadModelFile;
            ResultsMat.HeadModelType = HeadModelMat.HeadModelType;
            ResultsMat.ChannelFlag   = DataMat.ChannelFlag;
            ResultsMat.GoodChannel   = iChannelsData;
            ResultsMat.SurfaceFile   = HeadModelMat.SurfaceFile;
            ResultsMat.nAvg          = DataMat.nAvg;
            ResultsMat.Leff          = DataMat.Leff;
            ResultsMat.cfg           = ftSource.cfg;
            switch lower(ResultsMat.HeadModelType)
                case 'volume'
                    ResultsMat.GridLoc    = HeadModelMat.GridLoc;
                    % ResultsMat.GridOrient = [];
                case 'surface'
                    ResultsMat.GridLoc    = [];
                    % ResultsMat.GridOrient = [];
                case 'mixed'
                    ResultsMat.GridLoc    = HeadModelMat.GridLoc;
                    ResultsMat.GridOrient = HeadModelMat.GridOrient;
            end
            ResultsMat = bst_history('add', ResultsMat, 'compute', ['ft_sourceanalysis: ' Method ' ' Modality]);
            
            % === SAVE OUTPUT FILE ===
            % Output filename
            OutputDir = bst_fileparts(file_fullpath(DataFile));
            ResultFile = bst_process('GetNewFilename', OutputDir, ['results_', Method, '_', Modality, ]);
            % Save new file structure
            bst_save(ResultFile, ResultsMat, 'v6');

            % ===== REGISTER NEW FILE =====
            bst_progress('inc', 1);
            % Create new results structure
            newResult = db_template('results');
            newResult.Comment       = ResultsMat.Comment;
            newResult.FileName      = file_short(ResultFile);
            newResult.DataFile      = DataFile;
            newResult.isLink        = 0;
            newResult.HeadModelType = ResultsMat.HeadModelType;
            % Get output study
            sStudyData = bst_get('Study', iStudyData);
            % Add new entry to the database
            iResult = length(sStudyData.Result) + 1;
            sStudyData.Result(iResult) = newResult;
            % Update Brainstorm database
            bst_set('Study', iStudyData, sStudyData);
            % Store output filename
            OutputFiles{end+1} = newResult.FileName;
            % Expand data node
            panel_protocols('SelectNode', [], newResult.FileName);
        end
    end
    % Save database
    db_save();
    % Hide progress bar
    bst_progress('stop');
end



