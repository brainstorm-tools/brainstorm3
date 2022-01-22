function varargout = process_timefreq( varargin )
% PROCESS_TIMEFREQ: Computes the time frequency decomposition of any signal in the database.
% 
% USAGE:  sProcess = process_timefreq('GetDescription')
%           sInput = process_timefreq('Run',     sProcess, sInput)
%           TFmask = process_timefreq('GetEdgeEffectMask', Time, Freqs, tfOptions)

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
% Authors: Francois Tadel, 2010-2017

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Time-frequency (Morlet wavelets)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Frequency';
    sProcess.Index       = 505;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/TimeFrequency#Morlet_wavelets';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'matrix'};
    sProcess.OutputTypes = {'timefreq', 'timefreq', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Options: Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data'};
    sProcess.options.sensortypes.Group   = 'input';
    % Options: Scouts
    sProcess.options.clusters.Comment = '';
    sProcess.options.clusters.Type    = 'scout_confirm';
    sProcess.options.clusters.Value   = {};
    sProcess.options.clusters.InputTypes = {'results'};
    sProcess.options.clusters.Group   = 'input';
    % Options: Scout function
    sProcess.options.scoutfunc.Comment    = {'Mean', 'Max', 'PCA', 'Std', 'All', 'Scout function:'};
    sProcess.options.scoutfunc.Type       = 'radio_line';
    sProcess.options.scoutfunc.Value      = 1;
    sProcess.options.scoutfunc.InputTypes = {'results'};
    sProcess.options.scoutfunc.Group   = 'input';
    % Options: Time-freq
    sProcess.options.edit.Comment = {'panel_timefreq_options', 'Morlet wavelet options: '};
    sProcess.options.edit.Type    = 'editpref';
    sProcess.options.edit.Value   = [];
    % Options: Normalize
    sProcess.options.normalize2020.Comment = 'Spectral flattening: Multiply output power values by frequency';
    sProcess.options.normalize2020.Type    = 'checkbox';
    sProcess.options.normalize2020.Value   = 0;    
    % Old normalize option, for backwards compatibility.
    sProcess.options.normalize.Comment = {'<B>None</B>: Save non-standardized time-frequency maps', '<B>1/f compensation</B>: Multiply output values by frequency'; ...
                                          'none', 'multiply'};
    sProcess.options.normalize.Type    = 'radio_label';
    sProcess.options.normalize.Value   = 'none';
    sProcess.options.normalize.Hidden  = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Initialize returned values
    OutputFiles = {};
    % Extract method name from the process name
    switch (func2str(sProcess.Function))
        case 'process_timefreq',      strProcess = 'morlet';
        case 'process_hilbert',       strProcess = 'hilbert';
        case 'process_fft',           strProcess = 'fft';
        case 'process_psd',           strProcess = 'psd';
        case 'process_sprint',        strProcess = 'sprint';
        case 'process_ft_mtmconvol',  strProcess = 'mtmconvol';
        otherwise,                    error('Unsupported process.');
    end
    % Get editable options (Edit... button)
    if isfield(sProcess.options, 'edit')
        tfOPTIONS = sProcess.options.edit.Value;
        % If user did not edit values: get default values
        if isempty(tfOPTIONS)
            [bstPanelNew, panelName] = panel_timefreq_options('CreatePanel', sProcess, sInputs);
            jPanel = gui_show(bstPanelNew, 'JavaWindow', panelName, 0, 0, 0); 
            drawnow;
            tfOPTIONS = panel_timefreq_options('GetPanelContents');
            gui_hide(panelName);
        end
    % Else: get default options
    else
        tfOPTIONS = bst_timefreq();
        tfOPTIONS.Method = strProcess;
        switch tfOPTIONS.Method
            case 'fft',       tfOPTIONS.Comment = 'FFT';
            case 'psd',       tfOPTIONS.Comment = 'PSD';
            case 'sprint',    tfOPTIONS.Comment = 'SPRiNT';
            case 'morlet',    tfOPTIONS.Comment = 'Wavelet';
            case 'hilbert',   tfOPTIONS.Comment = 'Hilbert';
            case 'mtmconvol', tfOPTIONS.Comment = 'Multitaper';
        end
    end
    
    % Add other options
    tfOPTIONS.Method = strProcess;
    if isfield(sProcess.options, 'sensortypes')
        tfOPTIONS.SensorTypes = sProcess.options.sensortypes.Value;
    else
        tfOPTIONS.SensorTypes = [];
    end
    if isfield(sProcess.options, 'mirror') && ~isempty(sProcess.options.mirror) && ~isempty(sProcess.options.mirror.Value)
        tfOPTIONS.isMirror = sProcess.options.mirror.Value;
    else
        tfOPTIONS.isMirror = 0;
    end
    if isfield(sProcess.options, 'clusters') && ~isempty(sProcess.options.clusters) && ~isempty(sProcess.options.clusters.Value)
        tfOPTIONS.Clusters = sProcess.options.clusters.Value;
    else
        tfOPTIONS.Clusters = [];
    end
    % Override scouts function
    if isfield(sProcess.options, 'scoutfunc') && isfield(sProcess.options.scoutfunc, 'Value') && ~isempty(sProcess.options.scoutfunc.Value)
        switch lower(sProcess.options.scoutfunc.Value)
            case {1, 'mean'}, tfOPTIONS.ScoutFunc = 'mean';
            case {2, 'max'},  tfOPTIONS.ScoutFunc = 'max';
            case {3, 'pca'},  tfOPTIONS.ScoutFunc = 'pca';
            case {4, 'std'},  tfOPTIONS.ScoutFunc = 'std';
            case {5, 'all'},  tfOPTIONS.ScoutFunc = 'all';
            otherwise,  bst_report('Error', sProcess, [], 'Invalid scout function.');  return;
        end
    else
        tfOPTIONS.ScoutFunc = [];
    end
    % If a time window was specified
    if isfield(sProcess.options, 'timewindow') && ~isempty(sProcess.options.timewindow) && ~isempty(sProcess.options.timewindow.Value) && iscell(sProcess.options.timewindow.Value)
        tfOPTIONS.TimeWindow = sProcess.options.timewindow.Value{1};
    elseif ~isfield(tfOPTIONS, 'TimeWindow')
        tfOPTIONS.TimeWindow = [];
    end
    % If a window length was specified (PSD)
    if isfield(sProcess.options, 'win_length') && ~isempty(sProcess.options.win_length) && ~isempty(sProcess.options.win_length.Value) && iscell(sProcess.options.win_length.Value)
        tfOPTIONS.WinLength  = sProcess.options.win_length.Value{1};
        tfOPTIONS.WinOverlap = sProcess.options.win_overlap.Value{1};
    end
    if isfield(sProcess.options, 'win_std') && ~isempty(sProcess.options.win_std) && ~isempty(sProcess.options.win_std.Value)
        tfOPTIONS.WinStd = sProcess.options.win_std.Value;
        if tfOPTIONS.WinStd
            tfOPTIONS.Comment = [tfOPTIONS.Comment ' std'];
        end
    end
    % If units specified (PSD)
    if isfield(sProcess.options, 'units') && ~isempty(sProcess.options.units) && ~isempty(sProcess.options.units.Value)
        tfOPTIONS.PowerUnits = sProcess.options.units.Value;
    end    
    % Multitaper options
    if isfield(sProcess.options, 'mt_taper') && ~isempty(sProcess.options.mt_taper) && ~isempty(sProcess.options.mt_taper.Value)
        if iscell(sProcess.options.mt_taper.Value)
            tfOPTIONS.ft_mtmconvol.taper = sProcess.options.mt_taper.Value{1};
        else
            tfOPTIONS.ft_mtmconvol.taper = sProcess.options.mt_taper.Value;
        end
    end
    if isfield(sProcess.options, 'mt_frequencies') && ~isempty(sProcess.options.mt_frequencies) && ~isempty(sProcess.options.mt_frequencies.Value)
        tfOPTIONS.ft_mtmconvol.frequencies = eval(sProcess.options.mt_frequencies.Value);
        % Add frequencies to comment
        tfOPTIONS.Comment = [tfOPTIONS.Comment, ' ', sProcess.options.mt_frequencies.Value, 'Hz'];
    end
    if isfield(sProcess.options, 'mt_freqmod') && ~isempty(sProcess.options.mt_freqmod) && ~isempty(sProcess.options.mt_freqmod.Value)
        tfOPTIONS.ft_mtmconvol.freqmod = sProcess.options.mt_freqmod.Value{1};
    end
    if isfield(sProcess.options, 'mt_timeres') && ~isempty(sProcess.options.mt_timeres) && ~isempty(sProcess.options.mt_timeres.Value)
        tfOPTIONS.ft_mtmconvol.timeres = sProcess.options.mt_timeres.Value{1};
    end
    if isfield(sProcess.options, 'mt_timestep') && ~isempty(sProcess.options.mt_timestep) && ~isempty(sProcess.options.mt_timestep.Value)
        tfOPTIONS.ft_mtmconvol.timestep = sProcess.options.mt_timestep.Value{1};
    end
    if isfield(sProcess.options, 'measure') && ~isempty(sProcess.options.measure) && ~isempty(sProcess.options.measure.Value)
        tfOPTIONS.Measure = sProcess.options.measure.Value;
        % Add measure to comment
        if strcmpi(tfOPTIONS.Measure, 'none')
            strMeasure = 'complex';
        else
            strMeasure = tfOPTIONS.Measure;
        end
        tfOPTIONS.Comment = [tfOPTIONS.Comment, ' ', strMeasure];
    end
    % if process is SPRiNT
    if isfield(sProcess.options, 'fooof')
       tfOPTIONS.SPRiNTopts = sProcess.options;
    end
    % Output
    if isfield(sProcess.options, 'avgoutput') && ~isempty(sProcess.options.avgoutput) && ~isempty(sProcess.options.avgoutput.Value)
        if sProcess.options.avgoutput.Value
            tfOPTIONS.Output = 'average';
        else
            tfOPTIONS.Output = 'all';
        end
    end
    % Frequency normalization
    if isfield(sProcess.options, 'normalize2020') && ~isempty(sProcess.options.normalize2020) 
        if isequal(sProcess.options.normalize2020.Value, 1)
            tfOPTIONS.NormalizeFunc = 'multiply2020';
        elseif ischar(sProcess.options.normalize2020.Value)
            tfOPTIONS.NormalizeFunc = sProcess.options.normalize2020.Value;
        end
    elseif isfield(sProcess.options, 'normalize') && ~isempty(sProcess.options.normalize) 
        if isequal(sProcess.options.normalize.Value, 1)
            tfOPTIONS.NormalizeFunc = 'multiply';
        elseif ischar(sProcess.options.normalize.Value)
            tfOPTIONS.NormalizeFunc = sProcess.options.normalize.Value;
        end
    else
        tfOPTIONS.NormalizeFunc = 'none';
    end
    
    % === EXTRACT CLUSTER/SCOUTS ===
    if ~isempty(tfOPTIONS.Clusters)
        % If cluster function should be applied AFTER time-freq: get all time series
        if strcmpi(tfOPTIONS.ClusterFuncTime, 'after')
            ExtractScoutFunc = 'all';
        else
            ExtractScoutFunc = tfOPTIONS.ScoutFunc;
        end
        AddRowComment = ~isempty(tfOPTIONS.ScoutFunc) && strcmpi(tfOPTIONS.ScoutFunc, 'all');
        % Flip sign only for results
        isflip = strcmpi(sInputs(1).FileType, 'results');
        % Call process
        ClustMat = bst_process('CallProcess', 'process_extract_scout', sInputs, [], ...
            'timewindow',     tfOPTIONS.TimeWindow, ...
            'scouts',         tfOPTIONS.Clusters, ...
            'scoutfunc',      ExtractScoutFunc, ...  % If ScoutFunc is not defined, use the scout function available in each scout
            'isflip',         isflip, ...
            'isnorm',         0, ...
            'concatenate',    0, ...
            'save',           0, ...
            'addrowcomment',  AddRowComment, ...
            'addfilecomment', 0, ...
            'progressbar',    0);
        if isempty(ClustMat)
            bst_report('Error', sProcess, sInputs, 'Cannot access clusters/scouts time series.');
            return;
        end
        % Get data to process
        DataToProcess = {ClustMat.Value};
        tfOPTIONS.TimeVector  = ClustMat(1).Time;
        tfOPTIONS.ListFiles   = {sInputs.FileName};
        tfOPTIONS.nComponents = [ClustMat.nComponents];
        tfOPTIONS.RowNames    = {};
        tfOPTIONS.SurfaceFile = {ClustMat.SurfaceFile};
        for iFile = 1:length(ClustMat)
             tfOPTIONS.RowNames{iFile} = ClustMat(iFile).Description;
        end
        clear ClustMat;
    % === DATA FILES ===
    else
        DataToProcess = {sInputs.FileName};
        tfOPTIONS.TimeVector = in_bst(sInputs(1).FileName, 'Time');
    end

    % === OUTPUT STUDY ===
    if strcmpi(tfOPTIONS.Output, 'average')
        % Get output study
        [sStudy, iStudy, Comment] = bst_process('GetOutputStudy', sProcess, sInputs);
        % If no valid output study can be found
        if isempty(iStudy)
            return;
        end
        % Save all outputs from bst_timefreq in target Study
        tfOPTIONS.iTargetStudy = iStudy;
    else
        tfOPTIONS.iTargetStudy = [];
    end
    
    % === START COMPUTATION ===
    [OutputFiles, Messages, isError] = bst_timefreq(DataToProcess, tfOPTIONS);
    if ~isempty(Messages)
        if isError
            bst_report('Error', sProcess, sInputs, Messages);
        elseif isempty(OutputFiles)
            bst_report('Warning', sProcess, sInputs, Messages);
        else
            bst_report('Info', sProcess, sInputs, Messages);
            disp(['BST> process_timefreq: ' Messages]);
        end
    end
end


%% ===== GET EDGE EFFECT MASK =====
function TFmask = GetEdgeEffectMask(Time, Freqs, tfOptions) %#ok<DEFNU>
    % Get time vector
    if ~iscell(Time)
        t = Time;
    else
        t = mean(cell2mat(Time(:,2:3)), 2)';
    end
    % Get frequency vector
    if ~iscell(Freqs)
        f = Freqs;
    else
        FreqBands = process_tf_bands('GetBounds', Freqs);
        f = mean(FreqBands, 2)';
    end
    
    % Morlet wavelets
    if isfield(tfOptions, 'Method') && strcmpi(tfOptions.Method, 'morlet') && isfield(tfOptions, 'MorletFc') && isfield(tfOptions, 'MorletFwhmTc')
        FWHM_t = tfOptions.MorletFwhmTc * tfOptions.MorletFc ./ f;
        TF_timeres = repmat(FWHM_t' ./ 2, [1,length(t)]);
        TFmask = (bst_bsxfun(@minus, t - t(1), TF_timeres) > 0);
        TFmask = (TFmask & bst_flip(TFmask, 2));
  
    % Hilbert transform
    elseif isfield(tfOptions, 'Method') && strcmpi(tfOptions.Method, 'hilbert')
        if iscell(Time)
            disp('BST> Edge effects map for Hilbert process is not available yet when time bands are selected.');
            TFmask = [];
        else
            % Sampling frequency
            sfreq = 1 ./ (t(2) - t(1));
            % Compute the transients for each bandpass filter
            TFmask = zeros(size(Freqs,1), length(t));
            for i = 1:size(Freqs,1)
                % Compute the filter specifications
                [tmp, FiltSpec] = process_bandpass('Compute', [], sfreq, FreqBands(i,1), FreqBands(i,2), 'bst-hfilter-2019');
                % Only the values outside of the transients are valid
                TFmask(i,(t - t(1) > FiltSpec.transient) & (t(end) - t > FiltSpec.transient)) = 1;
            end
        end
    else
        TFmask = [];
    end
end


