function [TF, Messages, OPTIONS] = bst_sprint(F, sfreq, RowNames, OPTIONS)
% BST_SPRiNT: Compute time-resolved specparam models for a set of signals using
% an STFT approach.
% REFERENCE: Please cite the preprint for the SPRiNT algorithm:
%    Wilson, L. E., da Silva Castanheira, J., & Baillet, S. (2022). 
%    Time-resolved parameterization of aperiodic and periodic brain 
%    activity. eLife, 11, e77348. doi:10.7554/eLife.77348
% Please consider citing the specparam algorithm as well.

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
% Authors: Luc Wilson (2021)

% Fetch user settings
opt = struct();
opt.winLen              = OPTIONS.SPRiNTopts.win_length.Value{1};
opt.Ovrlp               = OPTIONS.SPRiNTopts.win_overlap.Value{1};
opt.nAverage            = OPTIONS.SPRiNTopts.loc_average.Value{1};
opt.freq_range          = OPTIONS.SPRiNTopts.freqrange.Value{1};
opt.peak_width_limits   = OPTIONS.SPRiNTopts.peakwidth.Value{1};
opt.max_peaks           = OPTIONS.SPRiNTopts.maxpeaks.Value{1};
opt.min_peak_height     = OPTIONS.SPRiNTopts.minpeakheight.Value{1} / 10; % convert from dB to B
opt.aperiodic_mode      = OPTIONS.SPRiNTopts.apermode.Value;
opt.peak_threshold      = 2;   % 2 std dev: parameter for interface simplification
opt.peak_type           = OPTIONS.SPRiNTopts.peaktype.Value;
opt.proximity_threshold = OPTIONS.SPRiNTopts.proxthresh.Value{1};
opt.guess_weight        = OPTIONS.SPRiNTopts.guessweight.Value;
opt.hOT = 0;
opt.thresh_after        = true;
opt.rmoutliers          = OPTIONS.SPRiNTopts.rmoutliers.Value;
opt.maxfreq             = OPTIONS.SPRiNTopts.maxfreq.Value{1};
opt.maxtime             = OPTIONS.SPRiNTopts.maxtime.Value{1};
opt.minnear             = OPTIONS.SPRiNTopts.minnear.Value{1};

if isfield(OPTIONS.SPRiNTopts,'imgK') % Source imaging
    isSource = 1;
    ImagingKernel = OPTIONS.SPRiNTopts.imgK;
else
    isSource = 0;
end

if license('test','optimization_toolbox') % check for optimization toolbox
    opt.hOT = 1;
    disp('Using constrained optimization, Guess Weight ignored.')
end

% Get sampling frequency
nTime = size(F,2);
% Initialize returned values
TF = [];
indGood = 1;                            % index for kept data
% ===== WINDOWING =====
bst_progress('start', 'SPRiNT', 'Standby: STFTing sensors', 0, 100);
Lwin  = round(opt.winLen * sfreq); % number of data points in windows
Loverlap = round(Lwin * opt.Ovrlp / 100); % number of data points in overlap
% If window is too small
Messages = [];
if (Lwin < 50)
    Messages = ['Time window is too small, please increase it and run the process again.' 10];
    return;
% If window is bigger than the data
elseif (Lwin > nTime)
    Lwin = size(F,2);
    Lwin = Lwin - mod(Lwin,2); % Make sure the number of samples is even
    Loverlap = 0;
    Nwin = 1;
    Messages = ['Time window is too large, using the entire recordings to estimate the spectrum.' 10];
% Else: there is at least one full time window
else
    Lwin = Lwin - mod(Lwin,2);    % Make sure the number of samples is even
    Nwin = floor((nTime - Loverlap) ./ (Lwin - Loverlap));
end
% Next power of 2 from length of signal
% NFFT = 2^nextpow2(Lwin);      % Function fft() pads the signal with zeros before computing the FT
NFFT = Lwin;                    % No zero-padding: Nfft = Ntime 
% Positive frequency bins spanned by FFT
FreqVector = sfreq / 2 * linspace(0,1,NFFT/2+1);
% Determine hamming window shape/power
Win = bst_window('hann', Lwin)';
WinNoisePowerGain = sum(Win.^2);
% Initialize STFT,time matrices
ts = nan(Nwin-(opt.nAverage-1),1);
% ===== CALCULATE FFT FOR EACH WINDOW =====
if isSource
    TF = nan(size(ImagingKernel,1), Nwin-(opt.nAverage-1), size(FreqVector,2));
    TFtmp = nan(size(ImagingKernel,1), opt.nAverage, size(FreqVector,2));
    TFfull = zeros(size(ImagingKernel,1),Nwin,size(FreqVector,2));
else
    TF = nan(size(F,1), Nwin-(opt.nAverage-1), size(FreqVector,2));
    TFtmp = nan(size(F,1), opt.nAverage, size(FreqVector,2));
    TFfull = zeros(size(F,1),Nwin,size(FreqVector,2));
end
for iWin = 1:Nwin
    % Build indices
    iTimes = (1:Lwin) + (iWin-1)*(Lwin - Loverlap);
    center_time = floor(median((iTimes-(opt.nAverage-1)./2*(Lwin - Loverlap))))./sfreq;
    % Select indices
    Fwin = F(:,iTimes);
    % No need to enforce removing DC component (0 frequency).
    Fwin = bst_bsxfun(@minus, Fwin, mean(Fwin,2));
    % Apply a Hann window to signal
    Fwin = bst_bsxfun(@times, Fwin, Win);
    % Compute FFT
    Ffft = fft(Fwin, NFFT, 2);
    % One-sided spectrum (keep only first half)
    % (x2 to recover full power from negative frequencies)
    % Normalize by the window "noise power gain" and convert "per
    % freq bin (or Hz⋅s)" to "per Hz".
    TFwin = Ffft(:,1:NFFT/2+1) * sqrt(2 ./ (sfreq * WinNoisePowerGain));
    % x2 doesn't apply to DC and Nyquist.
    TFwin(:, [1,end]) = TFwin(:, [1,end]) ./ sqrt(2);
    if isSource 
        TFwin = ImagingKernel * TFwin;
    end
    % Permute dimensions: time and frequency
    TFwin = permute(TFwin, [1 3 2]);
    % Convert to power
    TFwin = process_tf_measure('Compute', TFwin, 'none', 'power');
    TFfull(:,iWin,:) = TFwin;
    TFtmp(:,mod(iWin,opt.nAverage)+1,:) = TFwin;
    if isnan(TFtmp(1,1,1))
        continue
    else
    %     Save STFTs for window
        TF(:,indGood,:) = mean(TFtmp,2);
        ts(indGood) = center_time;
        indGood = indGood + 1;
    end
end
% trim excess time and TF slots 
TF(:,indGood:end,:) = [];
ts(indGood:end) = [];

% ===== GENERATE SPECPARAM MODELS FOR EACH WINDOW =====
% Find all frequency values within user limits
    fMask = (round(FreqVector.*10)./10 >= round(opt.freq_range(1).*10)./10) & (round(FreqVector.*10)./10 <= round(opt.freq_range(2).*10)./10);
    fs = FreqVector(fMask);
    OPTIONS.Freqs = fs;
    nChan = size(TF,1);
    nTimes = size(TF,2);
    % Adjust TF plots to only include modelled frequencies
    TF = TF(:,:,fMask);
    % Initalize FOOOF structs
    channel(nChan) = struct('name',[]);
    SPRiNT = struct('options',opt,'freqs',fs,'channel',channel,'SPRiNT_models',nan(size(TF)),'peak_models',nan(size(TF)),'aperiodic_models',nan(size(TF)));
    % Iterate across channels
    aperiodic_models = nan(nChan,nTimes,length(fs));
    peak_models = nan(nChan,nTimes,length(fs));
    SPRiNT_models = nan(nChan,nTimes,length(fs));
    tp_exponent = nan(nChan,nTimes);
    tp_offset = nan(nChan,nTimes);
    if isa(RowNames,'double')
        RowNames = cellstr(num2str(RowNames'));
    end
    for chan = 1:nChan
        channel(chan).name = RowNames{chan};
        bst_progress('text',['Standby: SPRiNTing sensor ' num2str(chan) ' of ' num2str(nChan)]);
        channel(chan).data(nTimes) = struct(...
            'time',             [],...
            'aperiodic_params', [],...
            'peak_params',      [],...
            'peak_types',       '',...
            'ap_fit',           [],...
            'fooofed_spectrum', [],...
            'power_spectrum',   [],...
            'peak_fit',         [],...
            'error',            [],...
            'r_squared',        []);
        channel(chan).peaks(nTimes*opt.max_peaks) = struct(...
            'time',             [],...
            'center_frequency', [],...
            'amplitude',        [],...
            'st_dev',           []);
        channel(chan).aperiodics(nTimes) = struct(...
            'time',             [],...
            'offset',           [],...
            'exponent',         []);
        channel(chan).stats(nTimes) = struct(...
            'MSE',              [],...
            'r_squared',        [],...
            'frequency_wise_error', []);
        spec = log10(squeeze(TF(chan,:,:))); % extract log spectra for a given channel
        % Iterate across time
        i = 1; % For peak extraction
        ag = -(spec(1,end)-spec(1,1))./log10(fs(end)./fs(1)); % aperiodic guess initialization
        for time = 1:nTimes
            bst_progress('set', bst_round(time / nTimes,2).*100);
            % Fit aperiodic 
            aperiodic_pars = robust_ap_fit(fs, spec(time,:), opt.aperiodic_mode, ag);
            % Remove aperiodic
            flat_spec = flatten_spectrum(fs, spec(time,:), aperiodic_pars, opt.aperiodic_mode);
            % Fit peaks
            [peak_pars, peak_function] = fit_peaks(fs, flat_spec, opt.max_peaks, opt.peak_threshold, opt.min_peak_height, ...
                opt.peak_width_limits/2, opt.proximity_threshold, opt.peak_type, opt.guess_weight,opt.hOT);
            if opt.thresh_after && ~opt.hOT  % Check thresholding requirements are met for unbounded optimization
                peak_pars(peak_pars(:,2) < opt.min_peak_height,:)     = []; % remove peaks shorter than limit
                peak_pars(peak_pars(:,3) < opt.peak_width_limits(1)/2,:)  = []; % remove peaks narrower than limit
                peak_pars(peak_pars(:,3) > opt.peak_width_limits(2)/2,:)  = []; % remove peaks broader than limit
                peak_pars = drop_peak_cf(peak_pars, opt.proximity_threshold, opt.freq_range); % remove peaks outside frequency limits
                peak_pars(peak_pars(:,1) < 0,:) = []; % remove peaks with a centre frequency less than zero (bypass drop_peak_cf)
                peak_pars = drop_peak_overlap(peak_pars, opt.proximity_threshold); % remove smallest of two peaks fit too closely
            end
            % Refit aperiodic
            aperiodic = spec(time,:);
            for peak = 1:size(peak_pars,1)
                aperiodic = aperiodic - peak_function(fs,peak_pars(peak,1), peak_pars(peak,2), peak_pars(peak,3));
            end
            aperiodic_pars = simple_ap_fit(fs, aperiodic, opt.aperiodic_mode, aperiodic_pars(end));
            ag = aperiodic_pars(end); % save aperiodic estimate for next iteration
            % Generate model fit
            ap_fit = gen_aperiodic(fs, aperiodic_pars, opt.aperiodic_mode);
            model_fit = ap_fit;
            for peak = 1:size(peak_pars,1)
                model_fit = model_fit + peak_function(fs,peak_pars(peak,1),...
                    peak_pars(peak,2),peak_pars(peak,3));
            end
            % Calculate model error
            MSE = sum((spec(time,:) - model_fit).^2)/length(model_fit);
            rsq_tmp = corrcoef(spec(time,:),model_fit).^2;
            % Return FOOOF results
            aperiodic_pars(2) = abs(aperiodic_pars(2));
            channel(chan).data(time).time                = ts(time);
            channel(chan).data(time).aperiodic_params    = aperiodic_pars;
            channel(chan).data(time).peak_params         = peak_pars;
            channel(chan).data(time).peak_types          = func2str(peak_function);
            channel(chan).data(time).ap_fit              = 10.^ap_fit;
            aperiodic_models(chan,time,:)                = 10.^ap_fit;
            channel(chan).data(time).fooofed_spectrum    = 10.^model_fit;
            SPRiNT_models(chan,time,:)                   = 10.^model_fit;
            channel(chan).data(time).power_spectrum   	 = 10.^spec(time,:);
            channel(chan).data(time).peak_fit            = 10.^(model_fit-ap_fit); 
            peak_models(chan,time,:)                     = 10.^(model_fit-ap_fit); 
            channel(chan).data(time).error               = MSE;
            channel(chan).data(time).r_squared           = rsq_tmp(2);
            % Extract peaks
            if ~isempty(peak_pars) & any(peak_pars)
                for p = 1:size(peak_pars,1)
                    channel(chan).peaks(i).time = ts(time);
                    channel(chan).peaks(i).center_frequency = peak_pars(p,1);
                    channel(chan).peaks(i).amplitude = peak_pars(p,2);
                    channel(chan).peaks(i).st_dev = peak_pars(p,3);
                    i = i +1;
                end
            end
            % Extract aperiodic
            channel(chan).aperiodics(time).time = ts(time);
            channel(chan).aperiodics(time).offset = aperiodic_pars(1);
            if length(aperiodic_pars)>2 % Legacy FOOOF alters order of parameters
                channel(chan).aperiodics(time).exponent = aperiodic_pars(3);
                channel(chan).aperiodics(time).knee_frequency = aperiodic_pars(2);
            else
                channel(chan).aperiodics(time).exponent = aperiodic_pars(2);
            end
            channel(chan).stats(time).MSE = MSE;
            channel(chan).stats(time).r_squared = rsq_tmp(2);
            channel(chan).stats(time).frequency_wise_error = abs(spec(time,:)-model_fit);
        end
        channel(chan).peaks(i:end) = [];
    end
    SPRiNT.channel = channel;
    SPRiNT.aperiodic_models = aperiodic_models;
    SPRiNT.SPRiNT_models = SPRiNT_models;
    SPRiNT.peak_models = peak_models;
    if strcmp(opt.rmoutliers,'yes')
        bst_progress('text','Standby: Removing outlier peaks');
        SPRiNT = remove_outliers(SPRiNT,peak_function,opt);
    end
    for chan = 1:nChan
        tp_exponent(chan,:) = [channel(chan).aperiodics(:).exponent];
        tp_offset(chan,:) = [channel(chan).aperiodics(:).offset];
    end
    SPRiNT.topography.exponent = tp_exponent;
    SPRiNT.topography.offset = tp_offset;
    bst_progress('text','Standby: Clustering modelled peaks');
    SPRiNT = cluster_peaks_dynamic(SPRiNT); % Cluster peaks
    OPTIONS.TimeVector = ts'; % Reassign times by windows used
    TF = sqrt(TF); % remove power transformation
    OPTIONS.SPRiNT = SPRiNT;
end

function SPRiNT = remove_outliers(SPRiNT,peak_function,opt)
%       Helper function to remove outlier peaks in SPRiNT models.
%
%       Parameters
%       ----------
%       SPRiNT : struct
%       	SPRiNT output struct.
%       peak_function : function
%       	Peak shape
%       opt : struct
%       	SPRiNT options structure
%
%       Returns
%       -------
%       SPRiNT : struct
%           SPRiNT output struct, with outlier peaks removed.
%
% Author: Luc Wilson

    timeRange = opt.maxtime.*opt.winLen.*(1-opt.Ovrlp./100);
    nC = length(SPRiNT.channel);
    for c = 1:nC
        bst_progress('set', bst_round(c / nC,2).*100);
        ts = [SPRiNT.channel(c).data.time];
        remove = 1;
        while any(remove) 
            remove = zeros(length([SPRiNT.channel(c).peaks]),1);
            for p = 1:length([SPRiNT.channel(c).peaks])
                if sum((abs([SPRiNT.channel(c).peaks.time] - SPRiNT.channel(c).peaks(p).time) <= timeRange) &...
                        (abs([SPRiNT.channel(c).peaks.center_frequency] - SPRiNT.channel(c).peaks(p).center_frequency) <= opt.maxfreq)) < opt.minnear +1 % includes current peak
                    remove(p) = 1;
                end
            end
            SPRiNT.channel(c).peaks(logical(remove)) = [];
        end
        
        for t = 1:length(ts)
            
            if SPRiNT.channel(c).data(t).peak_params(1) == 0
                continue % never any peaks to begin with
            end
            p = [SPRiNT.channel(c).peaks.time] == ts(t);
            if sum(p) == size(SPRiNT.channel(c).data(t).peak_params,1)
                continue % number of peaks has not changed
            end
            peak_fit = zeros(size(SPRiNT.freqs));
            if any(p)
                SPRiNT.channel(c).data(t).peak_params = [[SPRiNT.channel(c).peaks(p).center_frequency]' [SPRiNT.channel(c).peaks(p).amplitude]' [SPRiNT.channel(c).peaks(p).st_dev]'];
                peak_pars = SPRiNT.channel(c).data(t).peak_params;
                for peak = 1:size(peak_pars,1)
                    peak_fit = peak_fit + peak_function(SPRiNT.freqs,peak_pars(peak,1),...
                        peak_pars(peak,2),peak_pars(peak,3));
                end
                ap_spec = log10(SPRiNT.channel(c).data(t).power_spectrum) - peak_fit;
                ap_pars = simple_ap_fit(SPRiNT.freqs, ap_spec, opt.aperiodic_mode, SPRiNT.channel(c).data(t).aperiodic_params(end));
                ap_fit = gen_aperiodic(SPRiNT.freqs, ap_pars, opt.aperiodic_mode);
                MSE = sum((ap_spec - ap_fit).^2)/length(SPRiNT.freqs);
                rsq_tmp = corrcoef(ap_spec+peak_fit,ap_fit+peak_fit).^2;
                % Return FOOOF results
                ap_pars(2) = abs(ap_pars(2));
                SPRiNT.channel(c).data(t).ap_fit = 10.^(ap_fit);
                SPRiNT.channel(c).data(t).fooofed_spectrum = 10.^(ap_fit+peak_fit);
                SPRiNT.channel(c).data(t).peak_fit = 10.^(peak_fit);
                SPRiNT.channel(c).data(t).error = MSE;
                SPRiNT.channel(c).data(t).r_squared = rsq_tmp(2);
                SPRiNT.aperiodic_models(c,t,:) = SPRiNT.channel(c).data(t).ap_fit;
                SPRiNT.SPRiNT_models(c,t,:) = SPRiNT.channel(c).data(t).fooofed_spectrum;
                SPRiNT.peak_models(c,t,:) = SPRiNT.channel(c).data(t).peak_fit;
                SPRiNT.channel(c).aperiodics(t).offset = ap_pars(1);
                if length(ap_pars)>2 % Legacy FOOOF alters order of parameters
                    SPRiNT.channel(c).aperiodics(t).exponent = ap_pars(3);
                    SPRiNT.channel(c).aperiodics(t).knee_frequency = ap_pars(2);
                else
                    SPRiNT.channel(c).aperiodics(t).exponent = ap_pars(2);
                end
                SPRiNT.channel(c).stats(t).MSE = MSE;
                SPRiNT.channel(c).stats(t).r_squared = rsq_tmp(2);
                SPRiNT.channel(c).stats(t).frequency_wise_error = abs(ap_spec-ap_fit);
                
            else
                SPRiNT.channel(c).data(t).peak_params = [0 0 0];
                ap_spec = log10(SPRiNT.channel(c).data(t).power_spectrum) - peak_fit;
                ap_pars = simple_ap_fit(SPRiNT.freqs, ap_spec, opt.aperiodic_mode, SPRiNT.channel(c).data(t).aperiodic_params(end));
                ap_fit = gen_aperiodic(SPRiNT.freqs, ap_pars, opt.aperiodic_mode);
                MSE = sum((ap_spec - ap_fit).^2)/length(SPRiNT.freqs);
                rsq_tmp = corrcoef(ap_spec+peak_fit,ap_fit+peak_fit).^2;
                % Return FOOOF results
                ap_pars(2) = abs(ap_pars(2));
                SPRiNT.channel(c).data(t).ap_fit = 10.^(ap_fit);
                SPRiNT.channel(c).data(t).fooofed_spectrum = 10.^(ap_fit+peak_fit);
                SPRiNT.channel(c).data(t).peak_fit = 10.^(peak_fit);
                SPRiNT.aperiodic_models(c,t,:) = SPRiNT.channel(c).data(t).ap_fit;
                SPRiNT.SPRiNT_models(c,t,:) = SPRiNT.channel(c).data(t).fooofed_spectrum;
                SPRiNT.peak_models(c,t,:) = SPRiNT.channel(c).data(t).peak_fit;
                SPRiNT.channel(c).aperiodics(t).offset = ap_pars(1);
                if length(ap_pars)>2 % Legacy FOOOF alters order of parameters
                    SPRiNT.channel(c).aperiodics(t).exponent = ap_pars(3);
                    SPRiNT.channel(c).aperiodics(t).knee_frequency = ap_pars(2);
                else
                    SPRiNT.channel(c).aperiodics(t).exponent = ap_pars(2);
                end
                SPRiNT.channel(c).stats(t).MSE = MSE;
                SPRiNT.channel(c).stats(t).r_squared = rsq_tmp(2);
                SPRiNT.channel(c).stats(t).frequency_wise_error = abs(ap_spec-ap_fit);
            end
        end
    end
end

function oS = cluster_peaks_dynamic(oS)
%       Helper function to cluster peaks within sensors across time.
%
%       Parameters
%       ----------
%       oS : struct
%       	SPRiNT output struct.
%
%       Returns
%       -------
%       oS : struct
%           SPRiNT output struct, including clustered peaks field for each sensor.
%
% Author: Luc Wilson

    pthr = oS.options.proximity_threshold;
    for chan = 1:length(oS.channel)
        clustLead = [];
        nCl = 0;
        oS.channel(chan).clustered_peaks = struct();
        times = unique([oS.channel(chan).peaks.time]);
        all_peaks = oS.channel(chan).peaks;
        for time = 1:length(times)
            time_peaks = all_peaks([all_peaks.time] == times(time));
            % Initialize first clusters
            if time == 1
                nCl = length(time_peaks);
                for Cl = 1:nCl
                    oS.channel(chan).clustered_peaks(Cl).cluster = Cl;
                    oS.channel(chan).clustered_peaks(Cl).peaks(Cl) = time_peaks(Cl);
                    clustLead(Cl,1) = time_peaks(Cl).time;
                    clustLead(Cl,2) = time_peaks(Cl).center_frequency;
                    clustLead(Cl,3) = time_peaks(Cl).amplitude;
                    clustLead(Cl,4) = time_peaks(Cl).st_dev;
                    clustLead(Cl,5) = Cl;
                end
                continue
            end
            
            % Cluster "drafting stage": find points that make good matches to each cluster.  
            for Cl = 1:nCl
                match = abs([time_peaks.center_frequency]-clustLead(Cl,2))./clustLead(Cl,4) < pthr;
                idx_tmp = find(match);
                if any(match)
                    % Add the best candidate peak 
                    % Note: Auto-adds only peaks, but adds best candidate
                    % for multiple options
                    [tmp,idx] = min(([time_peaks(match).center_frequency] - clustLead(Cl,2)).^2 +...
                            ([time_peaks(match).amplitude] - clustLead(Cl,3)).^2 +...
                            ([time_peaks(match).st_dev] - clustLead(Cl,4)).^2);
                    oS.channel(chan).clustered_peaks(clustLead(Cl,5)).peaks(length(oS.channel(chan).clustered_peaks(clustLead(Cl,5)).peaks)+1) = time_peaks(idx_tmp(idx)); 
                    clustLead(Cl,1) = time_peaks(idx_tmp(idx)).time;
                    clustLead(Cl,2) = time_peaks(idx_tmp(idx)).center_frequency;
                    clustLead(Cl,3) = time_peaks(idx_tmp(idx)).amplitude;
                    clustLead(Cl,4) = time_peaks(idx_tmp(idx)).st_dev;
                    % Don't forget to remove the candidate from the pool
                    time_peaks(idx_tmp(idx)) = [];
                end
            end
            % Remaining peaks get sorted into their own clusters
            if ~isempty(time_peaks)
                for peak = 1:length(time_peaks)
                    nCl = nCl + 1;
                    Cl = nCl;
                    clustLead(Cl,1) = time_peaks(peak).time;
                    clustLead(Cl,2) = time_peaks(peak).center_frequency;
                    clustLead(Cl,3) = time_peaks(peak).amplitude;
                    clustLead(Cl,4) = time_peaks(peak).st_dev;
                    clustLead(Cl,5) = Cl;
                    oS.channel(chan).clustered_peaks(Cl).cluster = Cl;
                    oS.channel(chan).clustered_peaks(Cl).peaks(length(oS.channel(chan).clustered_peaks(clustLead(Cl,5)).peaks)+1) = time_peaks(peak); 
                end
            end     
            % Sort clusters based on most recent
            clustLead = sortrows(clustLead,1,'descend');
        end
    end
end

%% ===== GENERATE APERIODIC =====
function ap_vals = gen_aperiodic(freqs,aperiodic_params,aperiodic_mode)
%       Generate aperiodic values, from parameter definition.
%
%       Parameters
%       ----------
%       freqs : 1xn array
%       	Frequency vector to create aperiodic component for.
%       aperiodic_params : 1x3 array
%           Parameters that define the aperiodic component.
%       aperiodic_mode : {'fixed', 'knee'}
%           Defines absence or presence of knee in aperiodic component.
%
%       Returns
%       -------
%       ap_vals : 1d array
%           Generated aperiodic values.

    switch aperiodic_mode
        case 'fixed'  % no knee
            ap_vals = expo_nk_function(freqs,aperiodic_params);
        case 'knee'
            ap_vals = expo_function(freqs,aperiodic_params);
        case 'floor'
            ap_vals = expo_fl_function(freqs,aperiodic_params);
    end
end


%% ===== CORE MODELS =====
function ys = gaussian(freqs, mu, hgt, sigma)
%       Gaussian function to use for fitting.
%
%       Parameters
%       ----------
%       freqs : 1xn array
%           Frequency vector to create gaussian fit for.
%       mu, hgt, sigma : doubles
%           Parameters that define gaussian function (centre frequency,
%           height, and standard deviation).
%
%       Returns
%       -------
%       ys :    1xn array
%       Output values for gaussian function.

    ys = hgt*exp(-(((freqs-mu)./sigma).^2) /2);

end

function ys = cauchy(freqs, ctr, hgt, gam)
%       Cauchy function to use for fitting.
% 
%       Parameters
%       ----------
%       freqs : 1xn array
%           Frequency vector to create cauchy fit for.
%       ctr, hgt, gam : doubles
%           Parameters that define cauchy function (centre frequency,
%           height, and "standard deviation" [gamma]).
%
%       Returns
%       -------
%       ys :    1xn array
%       Output values for cauchy function.

    ys = hgt./(1+((freqs-ctr)/gam).^2);

end

function ys = expo_function(freqs,params)
%       Exponential function to use for fitting 1/f, with a 'knee' (maximum at low frequencies).
%
%       Parameters
%       ----------
%       freqs : 1xn array
%           Input x-axis values.
%       params : 1x3 array (offset, knee, exp)
%           Parameters (offset, knee, exp) that define Lorentzian function:
%           y = 10^offset * (1/(knee + x^exp))
%
%       Returns
%       -------
%       ys :    1xn array
%           Output values for exponential function.

    ys = params(1) - log10(abs(params(2)) +freqs.^params(3));

end

function ys = expo_nk_function(freqs, params)
%       Exponential function to use for fitting 1/f, without a 'knee'.
%
%       Parameters
%       ----------
%       freqs : 1xn array
%           Input x-axis values.
%       params : 1x2 array (offset, exp)
%           Parameters (offset, exp) that define Lorentzian function:
%           y = 10^offset * (1/(x^exp))
%
%       Returns
%       -------
%       ys :    1xn array
%           Output values for exponential (no-knee) function.

    ys = params(1) - log10(freqs.^params(2));

end

function ys = expo_fl_function(freqs, params)

    ys = log10(f.^(params(1)) * 10^(params(2)) + params(3));

end


%% ===== FITTING ALGORITHM =====
function aperiodic_params = simple_ap_fit(freqs, power_spectrum, aperiodic_mode, aperiodic_guess)
%       Fit the aperiodic component of the power spectrum.
%
%       Parameters
%       ----------
%       freqs : 1xn array
%           Frequency values for the power spectrum, in linear scale.
%       power_spectrum : 1xn array
%           Power values, in log10 scale.
%       aperiodic_mode : {'fixed','knee'}
%           Defines absence or presence of knee in aperiodic component.
%       aperiodic_guess: double
%           SPRiNT specific - feeds previous timepoint aperiodic slope as
%           guess
%
%       Returns
%       -------
%       aperiodic_params : 1xn array
%           Parameter estimates for aperiodic fit.

%       Set guess params for lorentzian aperiodic fit, guess params set at init
    options = optimset('Display', 'off', 'TolX', 1e-4, 'TolFun', 1e-6, ...
        'MaxFunEvals', 5000, 'MaxIter', 5000);

    switch (aperiodic_mode)
        case 'fixed'  % no knee
            guess_vec = [power_spectrum(1), aperiodic_guess];
            aperiodic_params = fminsearch(@error_expo_nk_function, guess_vec, options, freqs, power_spectrum);
        case 'knee'
            guess_vec = [power_spectrum(1),0, aperiodic_guess];
            aperiodic_params = fminsearch(@error_expo_function, guess_vec, options, freqs, power_spectrum);
    end

end

function aperiodic_params = robust_ap_fit(freqs, power_spectrum, aperiodic_mode, aperiodic_guess)
%       Fit the aperiodic component of the power spectrum robustly, ignoring outliers.
%
%       Parameters
%       ----------
%       freqs : 1xn array
%           Frequency values for the power spectrum, in linear scale.
%       power_spectrum : 1xn array
%           Power values, in log10 scale.
%       aperiodic_mode : {'fixed','knee'}
%           Defines absence or presence of knee in aperiodic component.
%       aperiodic_guess: double
%           SPRiNT specific - feeds previous timepoint aperiodic slope as
%           guess
%
%       Returns
%       -------
%       aperiodic_params : 1xn array
%           Parameter estimates for aperiodic fit.

    % Do a quick, initial aperiodic fit
    popt = simple_ap_fit(freqs, power_spectrum, aperiodic_mode, aperiodic_guess);
    initial_fit = gen_aperiodic(freqs, popt, aperiodic_mode);

    % Flatten power_spectrum based on initial aperiodic fit
    flatspec = power_spectrum - initial_fit;

    % Flatten outliers - any points that drop below 0
    flatspec(flatspec(:) < 0) = 0;

    % Use percential threshold, in terms of # of points, to extract and re-fit
    perc_thresh = bst_prctile(flatspec, 0.025);
    perc_mask = flatspec <= perc_thresh;
    freqs_ignore = freqs(perc_mask);
    spectrum_ignore = power_spectrum(perc_mask);

    % Second aperiodic fit - using results of first fit as guess parameters

    options = optimset('Display', 'off', 'TolX', 1e-4, 'TolFun', 1e-6, ...
        'MaxFunEvals', 5000, 'MaxIter', 5000);
    guess_vec = popt;

    switch (aperiodic_mode)
        case 'fixed'  % no knee
            aperiodic_params = fminsearch(@error_expo_nk_function, guess_vec, options, freqs_ignore, spectrum_ignore);
        case 'knee'
            aperiodic_params = fminsearch(@error_expo_function, guess_vec, options, freqs_ignore, spectrum_ignore);
    end
end

function spectrum_flat = flatten_spectrum(freqs, power_spectrum, robust_aperiodic_params, aperiodic_mode)
%       Flatten the power spectrum by removing the aperiodic component.
%
%       Parameters
%       ----------
%       freqs : 1xn array
%           Frequency values for the power spectrum, in linear scale.
%       power_spectrum : 1xn array
%           Power values, in log10 scale.
%       robust_aperiodic_params : 1x2 or 1x3 array (see aperiodic_mode)
%           Parameter estimates for aperiodic fit.
%       aperiodic_mode : 1 or 2
%           Defines absence or presence of knee in aperiodic component.
%
%       Returns
%       -------
%       spectrum_flat : 1xn array
%           Flattened (aperiodic removed) power spectrum.


spectrum_flat = power_spectrum - gen_aperiodic(freqs,robust_aperiodic_params,aperiodic_mode);

end

function [model_params,peak_function] = fit_peaks(freqs, flat_iter, max_n_peaks, peak_threshold, min_peak_height, gauss_std_limits, proxThresh, peakType, guess_weight,hOT)
%       Iteratively fit peaks to flattened spectrum.
%
%       Parameters
%       ----------
%       freqs : 1xn array
%           Frequency values for the power spectrum, in linear scale.
%       flat_iter : 1xn array
%           Flattened (aperiodic removed) power spectrum.
%       max_n_peaks : double
%           Maximum number of gaussians to fit within the spectrum.
%       peak_threshold : double
%           Threshold (in standard deviations of noise floor) to detect a peak.
%       min_peak_height : double
%           Minimum height of a peak (in log10).
%       gauss_std_limits : 1x2 double
%           Limits to gaussian (cauchy) standard deviation (gamma) when detecting a peak.
%       proxThresh : double
%           Minimum distance between two peaks, in st. dev. (gamma) of peaks.
%       peakType : {'gaussian', 'cauchy', 'both'}
%           Which types of peaks are being fitted
%       guess_weight : {'none', 'weak', 'strong'}
%           Parameter to weigh initial estimates during optimization (None, Weak, or Strong)
%       hOT : 0 or 1
%           Defines whether to use constrained optimization, fmincon, or
%           basic simplex, fminsearch.
%
%       Returns
%       -------
%       gaussian_params : mx3 array, where m = No. of peaks.
%           Parameters that define the peak fit(s). Each row is a peak, as [mean, height, st. dev. (gamma)].

    switch peakType 
        case 'gaussian' % gaussian only
            peak_function = @gaussian; % Identify peaks as gaussian
            % Initialize matrix of guess parameters for gaussian fitting.
            guess_params = zeros(max_n_peaks, 3);
            % Save intact flat_spectrum
            flat_spec = flat_iter;
            % Find peak: Loop through, finding a candidate peak, and fitting with a guess gaussian.
            % Stopping procedure based on either the limit on # of peaks,
            % or the relative or absolute height thresholds.
            for guess = 1:max_n_peaks
                % Find candidate peak - the maximum point of the flattened spectrum.
                max_ind = find(flat_iter == max(flat_iter));
                max_height = flat_iter(max_ind);

                % Stop searching for peaks once max_height drops below height threshold.
                if max_height <= peak_threshold * std(flat_iter)
                    break
                end

                % Set the guess parameters for gaussian fitting - mean and height.
                guess_freq = freqs(max_ind);
                guess_height = max_height;

                % Halt fitting process if candidate peak drops below minimum height.
                if guess_height <= min_peak_height
                    break
                end

                % Data-driven first guess at standard deviation
                % Find half height index on each side of the center frequency.
                half_height = 0.5 * max_height;

                le_ind = sum(flat_iter(1:max_ind) <= half_height);
                ri_ind = length(flat_iter) - sum(flat_iter(max_ind:end) <= half_height)+1;

                % Keep bandwidth estimation from the shortest side.
                % We grab shortest to avoid estimating very large std from overalapping peaks.
                % Grab the shortest side, ignoring a side if the half max was not found.
                % Note: will fail if both le & ri ind's end up as None (probably shouldn't happen).
                short_side = min(abs([le_ind,ri_ind]-max_ind));

                % Estimate std from FWHM. Calculate FWHM, converting to Hz, get guess std from FWHM
                fwhm = short_side * 2 * (freqs(2)-freqs(1));
                guess_std = fwhm / (2 * sqrt(2 * log(2)));

                % Check that guess std isn't outside preset std limits; restrict if so.
                % Note: without this, curve_fitting fails if given guess > or < bounds.
                if guess_std < gauss_std_limits(1)
                    guess_std = gauss_std_limits(1);
                end
                if guess_std > gauss_std_limits(2)
                    guess_std = gauss_std_limits(2);
                end

                % Collect guess parameters.
                guess_params(guess,:) = [guess_freq, guess_height, guess_std];

                % Subtract best-guess gaussian.
                peak_gauss = gaussian(freqs, guess_freq, guess_height, guess_std);
                flat_iter = flat_iter - peak_gauss;

            end
            % Remove unused guesses
            guess_params(guess_params(:,1) == 0,:) = [];

            % Check peaks based on edges, and on overlap
            % Drop any that violate requirements.
            guess_params = drop_peak_cf(guess_params, proxThresh, [min(freqs) max(freqs)]);
            guess_params = drop_peak_overlap(guess_params, proxThresh);

            % If there are peak guesses, fit the peaks, and sort results.
            if ~isempty(guess_params)
                model_params = fit_peak_guess(guess_params, freqs, flat_spec, 1, guess_weight, gauss_std_limits,hOT);
            else
                model_params = zeros(1, 3);
            end
            
        case 'cauchy' % cauchy only
            peak_function = @cauchy; % Identify peaks as cauchy
            guess_params = zeros(max_n_peaks, 3);
            flat_spec = flat_iter;
            for guess = 1:max_n_peaks
                max_ind = find(flat_iter == max(flat_iter));
                max_height = flat_iter(max_ind);
                if max_height <= peak_threshold * std(flat_iter)
                    break
                end
                guess_freq = freqs(max_ind);
                guess_height = max_height;
                if guess_height <= min_peak_height
                    break
                end
                half_height = 0.5 * max_height;
                le_ind = sum(flat_iter(1:max_ind) <= half_height);
                ri_ind = length(flat_iter) - sum(flat_iter(max_ind:end) <= half_height)+1;
                short_side = min(abs([le_ind,ri_ind]-max_ind));

                % Estimate gamma from FWHM. Calculate FWHM, converting to Hz, get guess gamma from FWHM
                fwhm = short_side * 2 * (freqs(2)-freqs(1));
                guess_gamma = fwhm/2;
                % Check that guess gamma isn't outside preset limits; restrict if so.
                % Note: without this, curve_fitting fails if given guess > or < bounds.
                if guess_gamma < gauss_std_limits(1)
                    guess_gamma = gauss_std_limits(1);
                end
                if guess_gamma > gauss_std_limits(2)
                    guess_gamma = gauss_std_limits(2);
                end

                % Collect guess parameters.
                guess_params(guess,:) = [guess_freq(1), guess_height, guess_gamma];

                % Subtract best-guess cauchy.
                peak_cauchy = cauchy(freqs, guess_freq(1), guess_height, guess_gamma);
                flat_iter = flat_iter - peak_cauchy;

            end
            guess_params(guess_params(:,1) == 0,:) = [];
            guess_params = drop_peak_cf(guess_params, proxThresh, [min(freqs) max(freqs)]);
            guess_params = drop_peak_overlap(guess_params, proxThresh);

            % If there are peak guesses, fit the peaks, and sort results.
            if ~isempty(guess_params)
                model_params = fit_peak_guess(guess_params, freqs, flat_spec, 2, guess_weight, gauss_std_limits,hOT);
            else
                model_params = zeros(1, 3);
            end
    end
            
end

function guess = drop_peak_cf(guess, bw_std_edge, freq_range)
%       Check whether to drop peaks based on center's proximity to the edge of the spectrum.
%
%       Parameters
%       ----------
%       guess : mx3 array, where m = No. of peaks.
%           Guess parameters for peak fits.
%
%       Returns
%       -------
%       guess : qx3 where q <= m No. of peaks.
%           Guess parameters for peak fits.

    cf_params = guess(:,1)';
    bw_params = guess(:,3)' * bw_std_edge;

    % Check if peaks within drop threshold from the edge of the frequency range.

    keep_peak = abs(cf_params-freq_range(1)) > bw_params & ...
        abs(cf_params-freq_range(2)) > bw_params;

    % Drop peaks that fail the center frequency edge criterion
    guess = guess(keep_peak,:);

end

function guess = drop_peak_overlap(guess, proxThresh)
%       Checks whether to drop gaussians based on amount of overlap.
%
%       Parameters
%       ----------
%       guess : mx3 array, where m = No. of peaks.
%           Guess parameters for peak fits.
%       proxThresh: double
%           Proximity threshold (in st. dev. or gamma) between two peaks.
%
%       Returns
%       -------
%       guess : qx3 where q <= m No. of peaks.
%           Guess parameters for peak fits.
%
%       Note
%       -----
%       For any gaussians with an overlap that crosses the threshold,
%       the lowest height guess guassian is dropped.

    % Sort the peak guesses, so can check overlap of adjacent peaks
    guess = sortrows(guess);

    % Calculate standard deviation bounds for checking amount of overlap

    bounds = [guess(:,1) - guess(:,3) * proxThresh, ...
        guess(:,1), guess(:,1) + guess(:,3) * proxThresh];

    % Loop through peak bounds, comparing current bound to that of next peak
    drop_inds =  [];

    for ind = 1:size(bounds,1)-1

        b_0 = bounds(ind,:);
        b_1 = bounds(ind + 1,:);

        % Check if bound of current peak extends into next peak
        if b_0(2) > b_1(1)
            % If so, get the index of the gaussian with the lowest height (to drop)
            drop_inds = [drop_inds (ind - 1 + find(guess(ind:ind+1,2) == ...
                min(guess(ind,2),guess(ind+1,2))))];
        end
    end
    % Drop any peaks guesses that overlap too much, based on threshold.
    guess(drop_inds,:) = [];
end

function peak_params = fit_peak_guess(guess, freqs, flat_spec, peak_type, guess_weight, std_limits, hOT)
%     Fits a group of peak guesses with a fit function.
%
%     Parameters
%     ----------
%       guess : mx3 array, where m = No. of peaks.
%           Guess parameters for peak fits.
%       freqs : 1xn array
%           Frequency values for the power spectrum, in linear scale.
%       flat_spec : 1xn array
%           Flattened (aperiodic removed) power spectrum.
%       peakType : {'gaussian', 'cauchy'}
%           Which types of peaks are being fitted.
%       guess_weight : 'none', 'weak', 'strong'
%           Parameter to weigh initial estimates during optimization.
%       std_limits: 1x2 array
%           Minimum and maximum standard deviations for distribution.
%       hOT : 0 or 1
%           Defines whether to use constrained optimization, fmincon, or
%           basic simplex, fminsearch.
%
%       Returns
%       -------
%       peak_params : mx3, where m =  No. of peaks.
%           Peak parameters post-optimization.

    
    if hOT % Use OptimToolbox for fmincon
        options = optimset('Display', 'off', 'TolX', 1e-3, 'TolFun', 1e-5, ...
        'MaxFunEvals', 3000, 'MaxIter', 3000); % Tuned options
        lb = [max([ones(size(guess,1),1).*freqs(1) guess(:,1)-guess(:,3)*2],[],2),zeros(size(guess(:,2))),ones(size(guess(:,3)))*std_limits(1)];
        ub = [min([ones(size(guess,1),1).*freqs(end) guess(:,1)+guess(:,3)*2],[],2),inf(size(guess(:,2))),ones(size(guess(:,3)))*std_limits(2)];
        peak_params = fmincon(@error_model_constr,guess,[],[],[],[], ...
            lb,ub,[],options,freqs,flat_spec, peak_type);
    else % Use basic simplex approach, fminsearch, with guess_weight
        options = optimset('Display', 'off', 'TolX', 1e-4, 'TolFun', 1e-5, ...
        'MaxFunEvals', 5000, 'MaxIter', 5000);
        peak_params = fminsearch(@error_model,...
            guess, options, freqs, flat_spec, peak_type, guess, guess_weight);
    end
end


%% ===== ERROR FUNCTIONS =====
function err = error_expo_nk_function(params,xs,ys)
    ym = -log10(xs.^params(2)) + params(1);
    err = sum((ys - ym).^2);
end

function err = error_expo_function(params,xs,ys)
    ym = expo_function(xs,params);
    err = sum((ys - ym).^2);
end

function err = error_model(params, xVals, yVals, peak_type, guess, guess_weight)
    fitted_vals = 0;
    weak = 1E2;
    strong = 1E7;
    for set = 1:size(params,1)
        switch (peak_type)
            case 1 % Gaussian
                fitted_vals = fitted_vals + gaussian(xVals, params(set,1), params(set,2), params(set,3));
            case 2 % Cauchy
                fitted_vals = fitted_vals + cauchy(xVals, params(set,1), params(set,2), params(set,3));
        end
    end
    switch guess_weight
        case 'none'
            err = sum((yVals - fitted_vals).^2);
        case 'weak' % Add small weight to deviations from guess m and amp
            err = sum((yVals - fitted_vals).^2) + ...
                 weak*sum((params(:,1)-guess(:,1)).^2) + ...
                 weak*sum((params(:,2)-guess(:,2)).^2);
        case 'strong' % Add large weight to deviations from guess m and amp
            err = sum((yVals - fitted_vals).^2) + ...
                 strong*sum((params(:,1)-guess(:,1)).^2) + ...
                 strong*sum((params(:,2)-guess(:,2)).^2);
    end
end

function err = error_model_constr(params, xVals, yVals, peak_type)
    fitted_vals = 0;
    for set = 1:size(params,1)
        switch (peak_type)
            case 1 % Gaussian
                fitted_vals = fitted_vals + gaussian(xVals, params(set,1), params(set,2), params(set,3));
            case 2 % Cauchy
                fitted_vals = fitted_vals + cauchy(xVals, params(set,1), params(set,2), params(set,3));
        end
    end
    err = sum((yVals - fitted_vals).^2);
end
