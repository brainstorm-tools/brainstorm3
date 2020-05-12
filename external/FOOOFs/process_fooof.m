function varargout = process_fooof(varargin)
% PROCESS_FOOOF: Applies the "Fitting Oscillations and One Over F"
% algorithm on a Welch's PSD

% @=============================================================================
% This software is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
%
% Copyright (c)2000-2020 Brainstorm by the University of Southern California
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPL
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
%

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'FOOOF';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Frequency';
    sProcess.Index       = 503;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Definition of the options
    % ===  FREQUENCY BAND
    sProcess.options.freqBand.Comment   = 'Frequency range for analysis';
    sProcess.options.freqBand.Type      = 'range';
    sProcess.options.freqBand.Value     = {[1, 40],'Hz',1};
    % ===  PEAK WIDTH LIMITS
    sProcess.options.peakWidthLimits.Comment = 'Peak width limits: ';
    sProcess.options.peakWidthLimits.Type    = 'range';
    sProcess.options.peakWidthLimits.Value   = {[0.5, 12], 'Hz', 1};
    % === MAX NUMBER OF PEAKS
    sProcess.options.maxPeaks.Comment = 'Maximum number of peaks: ';
    sProcess.options.maxPeaks.Type    = 'value';
    sProcess.options.maxPeaks.Value   = {3,'',0};
    % === MIN PEAK HEIGHT
    sProcess.options.minPeakHeight.Comment = 'Minimum peak height: ';
    sProcess.options.minPeakHeight.Type    = 'value';
    sProcess.options.minPeakHeight.Value   = {1,'Log-Power (dB)',1};
    % === PEAK THRESHOLD
    sProcess.options.peakThreshold.Comment = 'Peak threshold: ';
    sProcess.options.peakThreshold.Type    = 'value';
    sProcess.options.peakThreshold.Value   = {2,'stdev of noise',1};
    % === PROXIMITY THRESHOLD
    sProcess.options.proxThreshold.Comment = 'Proximity threshold: ';
    sProcess.options.proxThreshold.Type    = 'value';
    sProcess.options.proxThreshold.Value   = {2,'stdev of gaussian',1};
    % === APERIODIC MODE
    sProcess.options.aperiodicMode.Comment = {'Fixed', 'Knee', 'Aperiodic Mode:'};
    sProcess.options.aperiodicMode.Type    = 'radio_line';
    sProcess.options.aperiodicMode.Value   = 1;
    % === GUESS WEIGHT
    sProcess.options.guessWeight.Comment = {'None', 'Weak', 'Strong','Guess Weight:'};
    sProcess.options.guessWeight.Type    = 'radio_line';
    sProcess.options.guessWeight.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== GET OPTIONS =====
function [freqBand, peakWidthLims, maxPeaks, minPeakHeight, peakThresh, proxThresh, aperMode, guessWeight] = GetOptions(sProcess)
    freqBand = sProcess.options.freqBand.Value{1};
    peakWidthLims = sProcess.options.peakWidthLimits.Value{1};
    maxPeaks = sProcess.options.maxPeaks.Value{1};
    minPeakHeight = sProcess.options.minPeakHeight.Value{1}/10; % convert from ln to log10
    peakThresh = sProcess.options.peakThreshold.Value{1};
    proxThresh = sProcess.options.proxThreshold.Value{1};
    aperMode = sProcess.options.aperiodicMode.Value;
    guessWeight = sProcess.options.guessWeight.Value;
end

%% ===== RUN =====
function OutputFile = Run(sProcess, sInputs) %#ok<DEFNU>
    % Initialize returned list of files
    for iP = 1:length(sInputs)
        clear fg
        inputFile = in_bst_timefreq(sInputs(iP).FileName);
        [fB, pwl, maxp, minph, pet, prt, am, gw] = GetOptions(sProcess);
        OutputFile = {};
        % Check input frequency bounds
        if any(fB <= 0) || fB(1) >= fB(2)
            bst_report('error','Invalid Frequency range');
            return
        end
        fMask = round(inputFile.Freqs,1) >= fB(1) & inputFile.Freqs <= fB(2);
        fs = inputFile.Freqs(fMask);
        spec = log10(squeeze(inputFile.TF(:,1,fMask)));
        if any(fs == 0) % Model cannot handle 0 Hz input
            bst_report('error','Frequency range cannot include 0 Hz');
            return
        end
        % Initalize FOOOF structs
        fg(size(spec,1)) = struct('FOOOF',[]);
        for chan = 1:size(spec,1)
            bst_progress('set', round(chan / size(spec,1),2) * 100);
            % Fit aperiodic
            aperiodic_pars = robust_ap_fit(fs,spec(chan,:),am);
            % Remove aperiodic
            flat_spec = flatten_spectrum(fs,spec(chan,:),aperiodic_pars,am);
            % Fit peaks
            peak_pars = fit_peaks(fs,flat_spec,maxp,pet,minph,pwl/2,prt,gw);
            % Refit aperiodic
            aperiodic = spec(chan,:);
            for peak = 1:size(peak_pars,1)
                aperiodic = aperiodic - gaussian_function(fs,peak_pars(peak,1),...
                    peak_pars(peak,2),peak_pars(peak,3));
            end
            aperiodic_pars = simple_ap_fit(fs,aperiodic,am);
            % Generate model fit
            model_fit = gen_aperiodic(fs,aperiodic_pars,am);
            for peak = 1:size(peak_pars,1)
                model_fit = model_fit + gaussian_function(fs,peak_pars(peak,1),...
                    peak_pars(peak,2),peak_pars(peak,3));
            end
            % Calculate model error
            MSE = sum((spec(chan,:) - model_fit).^2)/length(model_fit);
            rsq_tmp = corrcoef(spec(chan,:),model_fit).^2;
            % Return FOOOF results
            fg(chan).FOOOF = struct(...
                'aperiodic_pars',   aperiodic_pars,...
                'peak_pars',        peak_pars,...
                'model_fit',        model_fit,...
                'error',            MSE,...
                'r_square',         rsq_tmp(2));
        end
        % Return FOOOF settings
        fp = struct('freq_range',           fB,...
                    'peak_width_limits',    pwl,...
                    'max_peaks',            maxp,...
                    'min_peak_height',      minph,...
                    'peak_threshold',       pet,...
                    'proximity_threshold',  prt,...
                    'aperiodic_mode',       am,...
                    'guess_weight',         gw);
        % Save file
        [~, iOutputStudy] = bst_process('GetOutputStudy', sProcess, sInputs(iP));
        OutputFile{end+1} = SaveFile(inputFile, fp, fs, fg, iOutputStudy);
    end
end

%% ===== SAVE FILE =====
function NewFile = SaveFile(inputFile, FOOOF_params, FOOOF_freqs, FOOOF_group, iOutputStudy)

    % ===== PREPARE OUTPUT STRUCTURE =====
    % Create file structure
    FileMat = inputFile;
    FileMat.FOOOF_params    = FOOOF_params;
    FileMat.FOOOF_freqs     = FOOOF_freqs;
    FileMat.FOOOF           = FOOOF_group;

    if contains(FileMat.Comment, 'PSD:')
        FileMat.Comment     = strrep(FileMat.Comment, 'PSD:', 'FOOOF:');
    else
        FileMat.Comment     = strcat(FileMat.Comment, ' | FOOOF');
    end
    % History: Computation
    FileMat = bst_history('add', FileMat, 'compute', 'FOOOF');
    % ===== SAVE FILE =====
    % Get output study
    sOutputStudy = bst_get('Study', iOutputStudy);
    % File tag
    fileTag = 'timefreq_psd';
    % Output filename
    NewFile = bst_process('GetNewFilename', bst_fileparts(sOutputStudy.FileName), fileTag);
    % Save file
    bst_save(NewFile, FileMat, 'v6');
    % Add file to database structure
    db_add_data(iOutputStudy, NewFile, FileMat);
end

%% Signal-generating function
function ap_vals = gen_aperiodic(freqs,aperiodic_params,aperiodic_mode)
%     Generate aperiodic values, from parameter definition.
%
%     Parameters
%     ----------
%     freqs : 1d array
%         Frequency vector to create aperiodic component for.
%     aperiodic_params : list of float
%         Parameters that define the aperiodic component.
%
%     Returns
%     -------
%     ap_vals : 1d array
%         Generated aperiodic values.

    if aperiodic_mode == 1 % no knee
        ap_vals = expo_nk_function(freqs,aperiodic_params);
    elseif aperiodic_mode == 2 % knee
        ap_vals = expo_function(freqs,aperiodic_params);
    end
end

%% From FOOOF core funcs
function ys = gaussian_function(xs, ctr, hgt, wid)
% Gaussian function to use for fitting.
%
%   Parameters
%   ----------
%   xs : 1d array
%       Input x-axis values.
%   *params : ctr, hgt, wid
%       Parameters that define gaussian function (centre frequency, height,
%       and standard deviation.
%
%   Returns
%   -------
%   ys : 1d array
%       Output values for gaussian function.

    ys = hgt*exp(-(xs-ctr).^2./(2*wid.^2));

end

function ys = expo_function(xs,params)
%   Exponential function to use for fitting 1/f, with a 'knee'.
%
%	NOTE: this function requires linear frequency (not log).
%
%	Parameters
%	----------
%	xs : 1d array
%       Input x-axis values.
%	params : float
%       Parameters (offset, knee, exp) that define Lorentzian function:
%	y = 10^offset * (1/(knee + x^exp))
%
%	Returns
%	-------
%	ys : 1d array
%       Output values for exponential function.

    ys = zeros(size(xs));

    ys = ys + params(1) - log10(params(2) +xs.^params(3));

end

function ys = expo_nk_function(xs, params)
%	Exponential function to use for fitting 1/f, with no 'knee'.
%
%   NOTE: this function requires linear frequency (not log).
%
%   Parameters
%	----------
%	xs : 1d array
%       Input x-axis values.
%	params : float
%       Parameters (a, c) that define Lorentzian function:
%       y = 10^off * (1/(x^exp))
%       a: constant; c: slope past knee
%
%	Returns
%	-------
%	ys : 1d array
%	Output values for exponential (no-knee) function.

    ys = zeros(size(xs));

    ys = ys + params(1) - log10(xs.^params(2));

end

%% From FOOOF fit script

function aperiodic_params = simple_ap_fit(freqs, power_spectrum, aperiodic_mode)
%         Fit the aperiodic component of the power spectrum.
%
%         Parameters
%         ----------
%         freqs : 1d array
%             Frequency values for the power_spectrum, in linear scale.
%         power_spectrum : 1d array
%             Power values, in log10 scale.
%
%         Returns
%         -------
%         aperiodic_params : 1d array
%             Parameter estimates for aperiodic fit.


%       Set guess params for lorentzian aperiodic fit, guess params set at init
    options = optimset('Display', 'off', 'TolX', 1e-6, 'TolFun', 1e-8, ...
        'MaxFunEvals', 5000, 'MaxIter', 5000);

    if aperiodic_mode == 1 % no knee
        guess_vec = [power_spectrum(1), 2];
        aperiodic_params = fminsearch(@error_expo_nk_function, guess_vec, options, freqs, power_spectrum);
    elseif aperiodic_mode == 2 % knee
        guess_vec = [power_spectrum(1),0, 2];
        aperiodic_params = fminsearch(@error_expo_function, guess_vec, options, freqs, power_spectrum);
    end

end

function aperiodic_params = robust_ap_fit(freqs, power_spectrum, aperiodic_mode)
%         Fit the aperiodic component of the power spectrum robustly, ignoring outliers.
%
%         Parameters
%         ----------
%         freqs : 1d array
%             Frequency values for the power spectrum, in linear scale.
%         power_spectrum : 1d array
%             Power values, in log10 scale.
%
%         Returns
%         -------
%         aperiodic_params : 1d array
%             Parameter estimates for aperiodic fit.


%       Do a quick, initial aperiodic fit
        popt = simple_ap_fit(freqs, power_spectrum, aperiodic_mode);
        initial_fit = gen_aperiodic(freqs, popt,aperiodic_mode);

%       Flatten power_spectrum based on initial aperiodic fit
        flatspec = power_spectrum - initial_fit;

%       Flatten outliers - any points that drop below 0
        flatspec(flatspec(:) < 0) = 0;

%       Use percential threshold, in terms of # of points, to extract and re-fit
        perc_thresh = prctile(flatspec, 2.5);
        perc_mask = flatspec <= perc_thresh;
        freqs_ignore = freqs(perc_mask);
        spectrum_ignore = power_spectrum(perc_mask);

%       Second aperiodic fit - using results of first fit as guess parameters
%       See note in _simple_ap_fit about warnings

    options = optimset('Display', 'off', 'TolX', 1e-6, 'TolFun', 1e-8, ...
        'MaxFunEvals', 5000, 'MaxIter', 5000);
    guess_vec = popt;

    if aperiodic_mode == 1 % no knee
        aperiodic_params = fminsearch(@error_expo_nk_function, guess_vec, options, freqs_ignore, spectrum_ignore);
    elseif aperiodic_mode == 2 % knee
        aperiodic_params = fminsearch(@error_expo_function, guess_vec, options, freqs, power_spectrum);
    end
end

function spectrum_flat = flatten_spectrum(freqs, power_spectrum, robust_aperiodic_params, aperiodic_mode)
%         Fit the aperiodic component of the power spectrum robustly, ignoring outliers.
%
%         Parameters
%         ----------
%         freqs : 1d array
%             Frequency values for the power spectrum, in linear scale.
%         power_spectrum : 1d array
%             Power values, in log10 scale.
%
%         Returns
%         -------
%         aperiodic_params : 1d array
%             Parameter estimates for aperiodic fit.


spectrum_flat = power_spectrum - gen_aperiodic(freqs,robust_aperiodic_params,aperiodic_mode);

end

function gaussian_params = fit_peaks(freqs, flat_iter, max_n_peaks, peak_threshold, min_peak_height, gauss_std_limits, proxThresh, guess_weight)
%         Iteratively fit peaks to flattened spectrum.
%
%         Parameters
%         ----------
%         freqs : 1d array
%             Frequency values for the power spectrum, in linear scale.
%         flat_iter : 1d array
%             Flattened power spectrum values.
%         max_n_peaks : int
%             Maximum number of gaussians within the spectrum
%         peak_threshold : float
%             Threshold (in standard deviations) to detect a peak
%         min_peak_height : float
%             Minimum height of a peak (in log10)
%
%         Returns
%         -------
%         gaussian_params : 2d array
%             Parameters that define the gaussian fit(s).
%             Each row is a gaussian, as [mean, height, standard deviation].


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
        ri_ind = length(flat_iter) - sum(flat_iter(max_ind:end) <= half_height);


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
        peak_gauss = gaussian_function(freqs, guess_freq, guess_height, guess_std);
        flat_iter = flat_iter - peak_gauss;

    end
    % Remove unused guesses
    guess_params(guess_params(:,1) == 0) = [];

    % Check peaks based on edges, and on overlap
    % Drop any that violate requirements.
    guess_params = drop_peak_cf(guess_params, 1, [min(freqs) max(freqs)]);
    guess_params = drop_peak_overlap(guess_params, proxThresh);

    % If there are peak guesses, fit the peaks, and sort results.
    if ~isempty(guess_params)
        gaussian_params = fit_peak_guess(guess_params, freqs, flat_spec, guess_weight);
    else
        gaussian_params = zeros(1, 3);
    end
end

function guess = drop_peak_cf(guess, bw_std_edge, freq_range)
%     Check whether to drop peaks based on center's proximity to the edge of the spectrum.
%
%     Parameters
%     ----------
%     guess : 2d array, shape=[n_peaks, 3]
%         Guess parameters for gaussian fits to peaks, as gaussian parameters.
%
%     Returns
%     -------
%     guess : 2d array, shape=[n_peaks, 3]
%         Guess parameters for gaussian fits to peaks, as gaussian parameters.


    cf_params = guess(:,1)';
    bw_params = guess(:,3)' * bw_std_edge;

    % Check if peaks within drop threshold from the edge of the frequency range.

    keep_peak = abs(cf_params-freq_range(1)) > bw_params & ...
        abs(cf_params-freq_range(1)) > bw_params;

    % Drop peaks that fail the center frequency edge criterion
    guess = guess(keep_peak,:);

end

function guess = drop_peak_overlap(guess, gauss_overlap_thresh)
%     Checks whether to drop gaussians based on amount of overlap.
%
%     Parameters
%     ----------
%     guess : 2d array, shape=[n_peaks, 3]
%         Guess parameters for gaussian fits to peaks, as gaussian parameters.
%
%     Returns
%     -------
%     guess : 2d array, shape=[n_peaks, 3]
%         Guess parameters for gaussian fits to peaks, as gaussian parameters.
%
%     Notes
%     -----
%     For any gaussians with an overlap that crosses the threshold,
%     the lowest height guess guassian is dropped.

    % Sort the peak guesses, so can check overlap of adjacent peaks
    guess = sortrows(guess);

    % Calculate standard deviation bounds for checking amount of overlap

    bounds = [guess(:,1) - guess(:,3) * gauss_overlap_thresh, ...
        guess(:,1), guess(:,1) + guess(:,3) * gauss_overlap_thresh];

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

function  gaussian_params = fit_peak_guess(guess, freqs, flat_spec, guess_weight)
%     Fits a group of peak guesses with a fit function.
%
%     Parameters
%     ----------
%     guess : 2d array, shape=[n_peaks, 3]
%         Guess parameters for gaussian fits to peaks, as gaussian parameters.
%
%     Returns
%     -------
%     gaussian_params : 2d array, shape=[n_peaks, 3]
%         Parameters for gaussian fits to peaks, as gaussian parameters.

    % Set the bounds for CF, enforce positive height value, and set bandwidth limits.
    % Note that 'guess' is in terms of gaussian std, so +/- BW is 2 * the guess_gauss_std.
    % This set of list comprehensions is a way to end up with bounds in the form:
    % ((cf_low_peak1, height_low_peak1, bw_low_peak1, *repeated for n_peaks*),
    % (cf_high_peak1, height_high_peak1, bw_high_peak, *repeated for n_peaks*))
    % ^where each value sets the bound on the specified parameter.

    options = optimset('Display', 'off', 'TolX', 1e-6, 'TolFun', 1e-8, ...
        'MaxFunEvals', 5000, 'MaxIter', 5000);

    gaussian_params = fminsearch(@error_gaussian,...
        guess, options, freqs, flat_spec, guess, guess_weight);

end

%% Error Functions

function err = error_expo_nk_function(params,xs,ys)
    ym = -log10(xs.^params(2)) + params(1);
    err = sum((ys - ym).^2);
end

function err = error_expo_function(params,xs,ys)
    ym = -log10(params(2) + xs.^params(3)) + params(1);
    err = sum((ys - ym).^2);
end

function err = error_gaussian(params, xVals, yVals, guess, guess_weight)
% error_gaussian
% Calculates error between data and a gaussian function, for use by fminsearch
% Params    - parameter vector (ampltude, mean, standard deviation)
% xVals     - values of independent variable
% yVals     - values of dependent variable (data points) at each of xVals

%     m  = params(1);
%     amp = params(2);
%     stdev = params(3);

    fitted_vals = 0;

    for set = 1:size(params,1)
        fitted_vals = fitted_vals + params(set,2)*exp(- ...
            (xVals-params(set,1)).^2/(2*params(set,3).^2));
    end
    switch guess_weight
        case 1
            err = sum((yVals - fitted_vals).^2);
        case 2
            err = sum((yVals - fitted_vals).^2) + ...
                 1E2*sum((params(:,1)-guess(:,1)).^2) + ...
                 1E2*sum((params(:,2)-guess(:,2)).^2);
        case 3
            err = sum((yVals - fitted_vals).^2) + ...
                 1E10*sum((params(:,1)-guess(:,1)).^2) + ...
                 1E10*sum((params(:,2)-guess(:,2)).^2);
    end
end
