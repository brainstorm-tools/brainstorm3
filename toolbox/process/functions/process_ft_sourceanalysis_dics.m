function varargout = process_ft_sourceanalysis_dics(varargin )
% PROCESS_FT_SOURCEANALYSIS Call FieldTrip function ft_sourceanalysis (DICS)

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
% Authors: Vahab YoussofZadeh, Francois Tadel, 2021

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'FieldTrip: ft_sourceanalysis (DICS)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Sources';
    sProcess.Index       = 357;
    sProcess.Description = 'https://github.com/vyoussofzadeh/DICS-beamformer-for-Brainstorm';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % Option: Sensors selection
    sProcess.options.sensortype.Comment = 'Sensor type:';
    sProcess.options.sensortype.Type    = 'combobox_label';
    sProcess.options.sensortype.Value   = {'MEG', {'MEG', 'MEG GRAD', 'MEG MAG', 'EEG', 'SEEG', 'ECOG'; ...
                                                   'MEG', 'MEG GRAD', 'MEG MAG', 'EEG', 'SEEG', 'ECOG'}};
    % Label: Time
    sProcess.options.label1.Comment = '<BR><B>Time of interest:</B>';
    sProcess.options.label1.Type    = 'label';
    % Active time window
    sProcess.options.poststim.Comment = 'Active (post-stim):';
    sProcess.options.poststim.Type    = 'poststim';
    sProcess.options.poststim.Value   = [];
    % Baseline time window
    sProcess.options.baseline.Comment = 'Baseline (pre-stim):';
    sProcess.options.baseline.Type    = 'baseline';
    sProcess.options.baseline.Value   = [];
    
    % Label: Frequency
    sProcess.options.label2.Comment = '<BR><B>Frequency of interset:</B>';
    sProcess.options.label2.Type    = 'label';
    % Enter the FOI in the data in Hz, eg, 22:
    sProcess.options.foi.Comment = 'FOI:';
    sProcess.options.foi.Type    = 'value';
    sProcess.options.foi.Value   = {18, 'Hz', 0};
    % Enter the Tapering frequency in the data in Hz, eg, 4:
    sProcess.options.tpr.Comment = 'Tapering freq:';
    sProcess.options.tpr.Type    = 'value';
    sProcess.options.tpr.Value   = {4, 'Hz', 0};

    % Label: Contrast
    sProcess.options.label4.Comment = '<BR><B>Contrasting analysis:</B>'; % Contrast between pre and post, across trials
    sProcess.options.label4.Type    = 'label';
    % Contrast
    sProcess.options.method.Comment = {'Subtraction (post-pre)', 'Permutation-stats (post-vs-pre)', 'Contrasting:'; ...
                                       'subtraction', 'permutation', ''};
    sProcess.options.method.Type    = 'radio_linelabel';
    sProcess.options.method.Value   = 'subtraction';
    % ERDS
    sProcess.options.erds.Comment = {'ERD', 'ERS', 'both', 'ERD/S effects:'; ...
                                     'erd', 'ers', 'both', ''};
    sProcess.options.erds.Type    = 'radio_linelabel';
    sProcess.options.erds.Value   = 'erd';
    % Effects
    sProcess.options.effect.Comment = {'abs', 'raw', 'Absolute/raw value of the contrast:'; ...
                                       'abs', 'raw', ''};
    sProcess.options.effect.Type    = 'radio_linelabel';
    sProcess.options.effect.Value   = 'abs';
    
    % Label: TFR
    sProcess.options.label3.Comment = '<BR><B>Time-freq response (used for data inspection):</B>';
    sProcess.options.label3.Type    = 'label';
    % Max frequency
    sProcess.options.maxfreq.Comment = 'Max frequency (for TFR calculation):';
    sProcess.options.maxfreq.Type    = 'value';
    sProcess.options.maxfreq.Value   = {40, 'Hz', 0};
    % Plot time-freq
    sProcess.options.showtfr.Comment = 'Plot time-frequency figure for visual';
    sProcess.options.showtfr.Type    = 'checkbox';
    sProcess.options.showtfr.Value   = 1;
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
Comment = sProcess.Comment;
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % Initialize FieldTrip
    [isInstalled, errMsg] = bst_plugin('Install', 'fieldtrip');
    if ~isInstalled
        bst_report('Error', sProcess, [], errMsg);
        return;
    end

    % ===== GET OPTIONS =====
    % Inverse options
    Method   = sProcess.options.method.Value;
    Modality = sProcess.options.sensortype.Value{1};
    ShowTfr  = sProcess.options.showtfr.Value;
    MaxFreq  = sProcess.options.maxfreq.Value{1};
    Baseline = sProcess.options.baseline.Value{1};
    PostStim = sProcess.options.poststim.Value{1};
    FOI      = sProcess.options.foi.Value{1};
    TprFreq  = sProcess.options.tpr.Value{1};
    % Output folder (for figures and FieldTrip structures)
    TmpDir = bst_get('BrainstormTmpDir');
    % Progress bar
    bst_progress('start', 'ft_sourceanalysis', 'Loading input files...', 0, 2*length(sInputs));

    % ===== LOAD: CHANNEL FILE =====
    bst_progress('text', 'Loading input files...');

    % Load channel file
    ChannelMat = in_bst_channel(sInputs(1).ChannelFile);
    % Get selected sensors
    iChannels = channel_find(ChannelMat.Channel, Modality);
    if isempty(iChannels)
        bst_report('Error', sProcess, sInputs, ['Channels "' Modality '" not found in channel file.']);
        return;
    end
    
    % ===== LOAD: BAD CHANNELS =====
    % Load bad channels from all the input files
    isChannelGood = [];
    for iInput = 1:length(sInputs)
        DataFile = sInputs(1).FileName;
        DataMat = load(file_fullpath(DataFile), 'ChannelFlag');
        if isempty(isChannelGood)
            isChannelGood = (DataMat.ChannelFlag == 1);
        elseif (length(DataMat.ChannelFlag) ~= length(isChannelGood)) || (length(DataMat.ChannelFlag) ~= length(ChannelMat.Channel))
            bst_report('Error', sProcess, sInputs, 'All the input files must have the same number of channels.');
            return;
        else
            isChannelGood = isChannelGood & (DataMat.ChannelFlag == 1);
        end
    end
    % Remove bad channels
    iChannelsData = intersect(iChannels, find(isChannelGood'));
    % Error: All channels tagged as bad
    if isempty(iChannelsData)
        bst_report('Error', sProcess, sInputs, 'All the selected channels are tagged as bad.');
        return;
    elseif any(~isChannelGood)
        bst_report('Info', sProcess, sInputs, ['Found ' num2str(length(find(~isChannelGood))) ' bad channels: ', sprintf('%s ', ChannelMat.Channel(find(~isChannelGood)).Name)]);
    end
    
    % ===== LOAD: HEADMODEL =====
    % Get the study
    sStudyChan = bst_get('ChannelFile', sInputs(1).ChannelFile);
    % Error if there is no head model available
    if isempty(sStudyChan.iHeadModel)
        bst_report('Error', sProcess, [], ['No head model available in folder: ' bst_fileparts(sStudyChan.FileName)]);
        return;
    end
    % Load head model
    HeadModelFile = sStudyChan.HeadModel(sStudyChan.iHeadModel).FileName;
    HeadModelMat = in_bst_headmodel(HeadModelFile);
    % Convert head model to FieldTrip format
    [ftHeadmodel, ftLeadfield, iChannelsData] = out_fieldtrip_headmodel(HeadModelMat, ChannelMat, iChannelsData, 1);

    % ===== LOAD: DATA =====
    % Template FieldTrip structure for all trials
    ftData = out_fieldtrip_data(sInputs(1).FileName, ChannelMat, iChannelsData, 1);
    ftData.trial = cell(1,length(sInputs));
    ftData.time = cell(1,length(sInputs));
    % Load all the trials
    
    AllChannelFiles = unique({sInputs.ChannelFile});
    iChanInputs = find(ismember({sInputs.ChannelFile}, AllChannelFiles{1}));
    for iInput = 1:length(sInputs)
        DataFile = sInputs(iChanInputs(iInput)).FileName;
        DataMat = in_bst_data(DataFile);
        ftData.trial{iInput} = DataMat.F(iChannelsData,:);
        ftData.time{iInput} = DataMat.Time;
    end
    
    
    % ===== FIELDTRIP: ft_freqanalysis =====
    bst_progress('text', 'Calling FieldTrip function: ft_freqanalysis...');
    % Compute tfr-decomposition
    cfg = [];
    cfg.output     = 'pow';
    cfg.channel    = 'all';
    cfg.method     = 'mtmconvol';
    cfg.taper      = 'hanning';
    cfg.foi        = 1:2:MaxFreq;
    cfg.keeptrials = 'yes';
    cfg.t_ftimwin  = 3 ./ cfg.foi;
    cfg.tapsmofrq  = 0.8 * cfg.foi;
    cfg.toi        = Baseline(1):0.05:PostStim(2);
    tfr            = ft_freqanalysis(cfg, ftData);
    % Plot TFR
    cfg = [];
    cfg.fmax = MaxFreq;
    cfg.toi = [Baseline(1), PostStim(2)];
    cfg.baselinetime = Baseline;
    cfg.plotflag = ShowTfr;
    [time_of_interest,freq_of_interest] = do_tfr_plot(cfg, tfr);
    disp(['Global max: time:',num2str(time_of_interest),'sec']);
    disp(['Global max: freq:',num2str(freq_of_interest),'Hz']);

    % ===== FIELDTRIP: EPOCHING =====
    % Baseline
    cfg = [];
    cfg.toilim = Baseline;
    ep_data.bsl = ft_redefinetrial(cfg, ftData);
    % Post-stim
    cfg.toilim = PostStim;
    ep_data.pst = ft_redefinetrial(cfg, ftData);
    % Baseline + Post-stim
    cfg = [];
    ep_data.app = ft_appenddata(cfg, ep_data.bsl, ep_data.pst);
    
    
    % ===== FIELDTRIP: SPECTRAL ANALYSIS =====
    cfg_main = [];
    cfg_main.fmax = MaxFreq;
    cfg_main.sens = ftData.grad;
    cfg_main.outputdir = TmpDir;
    cfg_main.freq_of_interest  = freq_of_interest; % Hz

    cfg = [];
    cfg.foilim    = [2 cfg_main.fmax];
    cfg.tapsmofrq = 1;
    cfg.taper     = 'hanning';
    f_data.bsl = do_fft(cfg, ep_data.bsl); f_data.bsl.elec = cfg_main.sens;
    f_data.pst = do_fft(cfg, ep_data.pst); f_data.pst.elec = cfg_main.sens;

    
    % ===== FIELDTRIP: PSD SENSOR SPACE =====
    outputdir_dics = cfg_main.outputdir;
    if exist(outputdir_dics, 'file') == 0, mkdir(outputdir_dics), end

    f_sugg = round(cfg_main.freq_of_interest);
    disp(['Suggested by TFR: ', num2str(f_sugg),'(+-3Hz)']);
    disp(['Select foi,eg ,', num2str(f_sugg),':']);
    
    cfg = [];
    cfg.foilim = [FOI, FOI];
    if (FOI >= 4)
        cfg.taper = 'dpss'; 
        cfg.tapsmofrq = TprFreq;
    else
        cfg.taper = 'hanning';
        cfg.tapsmofrq = 1;
    end

    f_data.app = do_fft(cfg, ep_data.app); f_data.app.elec = cfg_main.sens;
    f_data.bsl = do_fft(cfg, ep_data.bsl); f_data.bsl.elec = cfg_main.sens;
    f_data.pst = do_fft(cfg, ep_data.pst); f_data.pst.elec = cfg_main.sens;

    
    % ===== SOURCE ANALYSIS =====
    switch Method
        case 'subtraction'
            cfg = [];
            cfg.method = 'dics';
            cfg.dics.lambda = '100%';
            cfg.sourcemodel  = ftLeadfield;
            cfg.frequency    = f_data.app.freq;
            cfg.headmodel = ftHeadmodel;
            cfg.dics.keepfilter = 'yes';
            cfg.dics.fixedori    = 'yes'; % project on axis of most variance using SVD
            sourceavg = ft_sourceanalysis(cfg, f_data.app);

            cfg = [];
            cfg.method = 'dics';
            cfg.dics.lambda = '0%';
            cfg.sourcemodel        = ftLeadfield;
            cfg.sourcemodel.filter = sourceavg.avg.filter;
            cfg.dics.fixedori    = 'yes'; % project on axis of most variance using SVD
            cfg.headmodel = ftHeadmodel;
            s_data.bsl      = ft_sourceanalysis(cfg, f_data.bsl);
            s_data.pst      = ft_sourceanalysis(cfg, f_data.pst);

            switch sProcess.options.erds.Value
                case 'erd'
                    cfg = [];
                    cfg.parameter = 'pow';
                    cfg.operation = 'log10(x1/x2)'; % sourceA divided by sourceB
                    source_diff_dics = ft_math(cfg, s_data.pst, s_data.bsl);
                    source_diff_dics.pow(isnan(source_diff_dics.pow))=0;
                    source_diff_dics.pow(source_diff_dics.pow>0)=0;
                case 'ers'
                    cfg = [];
                    cfg.parameter = 'pow';
                    cfg.operation = 'log10(x1/x2)'; % sourceA divided by sourceB
                    source_diff_dics = ft_math(cfg, s_data.pst, s_data.bsl);
                    source_diff_dics.pow(isnan(source_diff_dics.pow))=0;
                    source_diff_dics.pow(source_diff_dics.pow<0)=0;
                case 'both'
                    cfg = [];
                    cfg.parameter = 'pow';
                    cfg.operation = 'log10(x1/x2)'; % sourceA divided by sourceB
                    source_diff_dics = ft_math(cfg,s_data.pst,s_data.bsl);
                    source_diff_dics.pow(isnan(source_diff_dics.pow))=0;
            end

        case 'permutation'
            cfg = [];
            cfg.method = 'dics';
            cfg.dics.lambda = '100%';
            cfg.frequency    = f_data.app.freq;
            cfg.headmodel = ftHeadmodel;
            cfg.sourcemodel  = ftLeadfield;
            cfg.dics.keepfilter = 'yes';
            cfg.dics.fixedori    = 'yes'; % project on axis of most variance using SVD
            sourceavg = ft_sourceanalysis(cfg, f_data.app);

            cfg = [];
            cfg.method = 'dics';
            cfg.sourcemodel        = ftLeadfield;
            cfg.sourcemodel.filter = sourceavg.avg.filter;
            cfg.dics.fixedori    = 'yes'; % project on axis of most variance using SVD
            cfg.rawtrial = 'yes';
            cfg.headmodel = ftHeadmodel;
            s_data.bsl      = ft_sourceanalysis(cfg, f_data.bsl);
            s_data.pst      = ft_sourceanalysis(cfg, f_data.pst);

            stat = do_source_stat_montcarlo(s_data);

            tmp = stat.stat;
            tmp2 = zeros(size(stat.pos,1),1);
            tmp2(stat.inside) = tmp;

            stats1  = stat;
            stats1.stat =  tmp2;
            stats1.mask = stat.inside;
            stats2 = stats1;
            stats2.stat(stats2.stat>0)=0;
            stats2.stat(isnan(stats2.stat))=0;
    end

    
    % ===== SAVE RESULTS =====
    % === CREATE OUTPUT STRUCTURE ===
    bst_progress('text', 'Saving source file...');
    bst_progress('inc', 1);
    % Output study
    if (length(sInputs) == 1)
        iStudyOut = sInputs(1).iStudy;
        RefDataFile = sInputs(iChanInputs(iInput)).FileName;
    else
        [tmp, iStudyOut] = bst_process('GetOutputStudy', sProcess, sInputs);
        RefDataFile = [];
    end
    % Create structure
    ResultsMat = db_template('resultsmat');
    ResultsMat.ImagingKernel = [];
    switch Method
        case 'subtraction'
            switch sProcess.options.effect.Value
                case 'abs'
                    source_diff_dics.pow = abs((source_diff_dics.pow));
                case 'raw'
                    source_diff_dics.pow = source_diff_dics.pow;
            end
            ResultsMat.ImageGridAmp  = source_diff_dics.pow;
            ResultsMat.cfg           = source_diff_dics.cfg;

        case 'permutation'
            switch sProcess.options.effect.Value
                case 'abs'
                    stats2.stat = abs((stats2.stat));
                case 'raw'
                    stats2.stat = stats2.stat;
            end
            ResultsMat.ImageGridAmp  = stats2.stat;
            ResultsMat.cfg           = stat.cfg;
    end
    ResultsMat.nComponents   = 1;
    ResultsMat.Function      = Method;
    ResultsMat.Time          = 1;
    ResultsMat.DataFile      = RefDataFile;
    ResultsMat.HeadModelFile = HeadModelFile;
    ResultsMat.HeadModelType = HeadModelMat.HeadModelType;
    ResultsMat.ChannelFlag   = DataMat.ChannelFlag;
    ResultsMat.GoodChannel   = iChannelsData;
    ResultsMat.SurfaceFile   = HeadModelMat.SurfaceFile;
    ResultsMat.nAvg          = DataMat.nAvg;
    ResultsMat.Leff          = DataMat.Leff;
    ResultsMat.Comment       = ['DICS: ' Method, ' ',num2str(FOI),'Hz ', sprintf('%1.3fs-%1.3fs', PostStim)];
    switch lower(ResultsMat.HeadModelType)
        case 'volume'
            ResultsMat.GridLoc    = HeadModelMat.GridLoc;
        case 'surface'
            ResultsMat.GridLoc    = [];
        case 'mixed'
            ResultsMat.GridLoc    = HeadModelMat.GridLoc;
            ResultsMat.GridOrient = HeadModelMat.GridOrient;
    end
    ResultsMat = bst_history('add', ResultsMat, 'compute', ['ft_sourceanalysis: ' Method ' ' Modality ' ']);

    % === SAVE OUTPUT FILE ===
    % Output filename
    OutputDir = bst_fileparts(file_fullpath(DataFile));
    ResultFile = bst_process('GetNewFilename', OutputDir, ['results_', Method, '_', Modality]);
    % Save new file structure
    bst_save(ResultFile, ResultsMat, 'v6');

    % ===== REGISTER NEW FILE =====
    % Create new results structure
    newResult = db_template('results');
    newResult.Comment       = ResultsMat.Comment;
    newResult.FileName      = file_short(ResultFile);
    newResult.DataFile      = ResultsMat.DataFile;
    newResult.isLink        = 0;
    newResult.HeadModelType = ResultsMat.HeadModelType;
    % Get output study
    sStudyOut = bst_get('Study', iStudyOut);
    % Add new entry to the database
    iResult = length(sStudyOut.Result) + 1;
    sStudyOut.Result(iResult) = newResult;
    % Update Brainstorm database
    bst_set('Study', iStudyOut, sStudyOut);
    % Store output filename
    OutputFiles{end+1} = newResult.FileName;
    % Expand data node
    panel_protocols('SelectNode', [], newResult.FileName);

    % Save database
    db_save();
    % Hide progress bar
    bst_progress('stop');
end



%% ===== TIME-FREQUENCY =====
function [time_of_interest,freq_of_interest] = do_tfr_plot(cfg_main, tfr)
    % First compute the average over trials:
    cfg = [];
    freq_avg = ft_freqdescriptives(cfg, tfr);

    % And baseline-correct the average:
    cfg = [];
    cfg.baseline = cfg_main.baselinetime;
    cfg.baselinetype = 'db'; % Use decibel contrast here
    freq_avg_bsl = ft_freqbaseline(cfg, freq_avg);

    freq_avg_bsl.powspctrm(isnan(freq_avg_bsl.powspctrm))=0;
    meanpow = squeeze(mean(freq_avg_bsl.powspctrm, 1));

    tim_interp = linspace(cfg_main.toi(1), cfg_main.toi(2), 512);
    freq_interp = linspace(1, cfg_main.fmax, 512);

    % We need to make a full time/frequency grid of both the original and
    % interpolated coordinates. Matlab's meshgrid() does this for us:
    [tim_grid_orig, freq_grid_orig] = meshgrid(tfr.time, tfr.freq);
    [tim_grid_interp, freq_grid_interp] = meshgrid(tim_interp, freq_interp);

    % And interpolate:
    pow_interp = interp2(tim_grid_orig, freq_grid_orig, meanpow, tim_grid_interp, freq_grid_interp, 'spline');
    
    % while n==1
    pow_interp1  = pow_interp(50:end,50:end);
    tim_interp1  = tim_interp(50:end);
    freq_interp1 = freq_interp(50:end);


    [~,idx] = min(pow_interp1(:));
    [row,col] = ind2sub(size(pow_interp1),idx);

    time_of_interest = tim_interp1(col);
    freq_of_interest = freq_interp1(row);

    timind = nearest(tim_interp, time_of_interest);
    freqind = nearest(freq_interp, freq_of_interest);
    pow_at_toi = pow_interp(:,timind);
    pow_at_foi = pow_interp(freqind,:);


    % Plot figure
    if cfg_main.plotflag
        figure();
        ax_main  = axes('Position', [0.1 0.2 0.55 0.55]);
        ax_right = axes('Position', [0.7 0.2 0.1 0.55]);
        ax_top   = axes('Position', [0.1 0.8 0.55 0.1]);

        axes(ax_main);
        imagesc(tim_interp, freq_interp, pow_interp);
        % note we're storing a handle to the image im_main, needed later on
        xlim([cfg_main.toi(1), cfg_main.toi(2)]);
        axis xy;
        xlabel('Time (s)');
        ylabel('Frequency (Hz)');
        clim = max(abs(meanpow(:)));
        caxis([-clim clim]);
        % colormap(brewermap(256, '*RdYlBu'));
        hold on;
        plot(zeros(size(freq_interp)), freq_interp, 'k:');

        axes(ax_top);
        area(tim_interp, pow_at_foi, ...
            'EdgeColor', 'none', 'FaceColor', [0.5 0.5 0.5]);
        xlim([cfg_main.toi(1), cfg_main.toi(2)]);
        ylim([-clim clim]);
        box off;
        ax_top.XTickLabel = [];
        ylabel('Power (dB)');
        hold on;
        plot([0 0], [-clim clim], 'k:');

        axes(ax_right);
        area(freq_interp, pow_at_toi,...
            'EdgeColor', 'none', 'FaceColor', [0.5 0.5 0.5]);
        view([270 90]); % this rotates the plot
        ax_right.YDir = 'reverse';
        ylim([-clim clim]);
        box off;
        ax_right.XTickLabel = [];
        ylabel('Power (dB)');

        h = colorbar(ax_main, 'manual', 'Position', [0.85 0.2 0.05 0.55]);
        ylabel(h, 'Power vs baseline (dB)');

        % Main plot:
        axes(ax_main);
        plot(ones(size(freq_interp))*time_of_interest, freq_interp,...
            'Color', [0 0 0 0.1], 'LineWidth', 3);
        plot(tim_interp, ones(size(tim_interp))*freq_of_interest,...
            'Color', [0 0 0 0.1], 'LineWidth', 3);

        % Marginals:
        axes(ax_top);
        plot([time_of_interest time_of_interest], [0 clim],...
            'Color', [0 0 0 0.1], 'LineWidth', 3);
        axes(ax_right);
        hold on;
        plot([freq_of_interest freq_of_interest], [0 clim],...
            'Color', [0 0 0 0.1], 'LineWidth', 3);
    end
end


function [freq,ff, psd,tapsmofrq] = do_fft(cfg_mian, data)
    cfg              = [];
    cfg.method       = 'mtmfft';
    cfg.output       = 'fourier';
    cfg.keeptrials   = 'yes';
    cfg.foilim       = cfg_mian.foilim;
    cfg.tapsmofrq    = cfg_mian.tapsmofrq;
    cfg.taper        = cfg_mian.taper;
    cfg.pad          = 4;
    freq             = ft_freqanalysis(cfg, data);
    psd = squeeze(mean(mean(abs(freq.fourierspctrm),2),1));
    ff = linspace(1, cfg.foilim(2), length(psd));

    tapsmofrq = cfg.tapsmofrq;
end


function stat = do_source_stat_montcarlo(s_data)
    cfg = [];
    cfg.parameter        = 'pow';
    cfg.method           = 'montecarlo';
    cfg.statistic        = 'depsamplesT';
    cfg.correctm         = 'fdr';
    cfg.clusteralpha     = 0.001;
    cfg.tail             = 0;
    cfg.clustertail      = 0;
    cfg.alpha            = 0.05;
    cfg.numrandomization = 5000;

    ntrials                       = numel(s_data.bsl.trial);
    design                        = zeros(2,2*ntrials);
    design(1,1:ntrials)           = 1;
    design(1,ntrials+1:2*ntrials) = 2;
    design(2,1:ntrials)           = 1:ntrials;
    design(2,ntrials+1:2*ntrials) = 1:ntrials;

    cfg.design   = design;
    cfg.ivar     = 1;
    cfg.uvar     = 2;
    stat         = ft_sourcestatistics(cfg,s_data.pst,s_data.bsl);
end
