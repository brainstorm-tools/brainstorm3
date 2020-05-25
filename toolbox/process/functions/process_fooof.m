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
    % ===  FOOOF TYPE ===
    sProcess.options.fooofType.Comment   = {'Matlab', 'Python', 'FOOOF version:'};
    sProcess.options.fooofType.Type      = 'radio_line';
    sProcess.options.fooofType.Value     = 1;
    % === Options: FOOOF ===
    sProcess.options.edit.Comment = {'panel_fooof_options', ' FOOOF options: '};
    sProcess.options.edit.Type    = 'editpref';
    sProcess.options.edit.Value   = [];
    % === * EXPLANATION ===
    sProcess.options.explanation.Comment = '<U><B>* Python Version Requires Python 3 (3.7 preferred) *</B></U>';
    sProcess.options.explanation.Type    = 'label';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== GET OPTIONS =====
function [fooofType, freqBand, peakType, peakWidthLims, maxPeaks, minPeakHeight, peakThresh, proxThresh, aperMode, guessWeight] = GetOptions(sProcess)
    fooofType = sProcess.options.fooofType.Value;
    opts = panel_fooof_options('GetPanelContents');
    freqBand = opts.freqRange;
    peakWidthLims = opts.peakWidthLimits;
    maxPeaks = opts.maxPeaks;
    minPeakHeight = opts.minPeakHeight/10; % convert from dB to B
    peakThresh = opts.peakThresh;
    aperMode = opts.aperMode;
    if fooofType == 1
        proxThresh = opts.proxThresh;    
        guessWeight = opts.guessWeight;
        peakType = opts.peakType;
    else
        proxThresh = []; guessWeight = []; peakType = [];
    end
end

%% ===== RUN =====
function OutputFile = Run(sProcess, sInputs) %#ok<DEFNU>
    % Fetch user settings
    [fT, fB, pt, pwl, maxp, minph, pet, prt, am, gw] = GetOptions(sProcess);
    if fT == 1 % Matlab standalone FOOOF
        OutputFile = FOOOF_matlab(sProcess, sInputs, fB, pt, pwl, maxp, minph, pet, prt, am, gw);  
    else % Python FOOOF
        OutputFile = FOOOF_python(sProcess, sInputs, fB, pwl, maxp, minph, pet, am);
    end    
end

%% ===== MATLAB STANDALONE FOOOF =====
function OutputFile = FOOOF_matlab(sProcess, sInputs, fB, pt, pwl, maxp, minph, pet, prt, am, gw)
    switch pt
        case 1,     pts = 'gaussian';
        case 2,     pts = 'cauchy';
        case 3,     pts = 'best of both';
    end
    switch am
        case 1,     ams = 'fixed';
        case 2,     ams = 'knee';
    end
    switch gw
        case 1,     gws = 'none';
        case 2,     gws = 'weak';
        case 3,     gws = 'strong';
    end
    for iP = 1:length(sInputs)
        bst_progress('text',['Standby: FOOOFing spectrum ' num2str(iP) ' of ' num2str(length(sInputs))]);
        clear fg
        inputFile = in_bst_timefreq(sInputs(iP).FileName);
        % Initialize returned list of files
        OutputFile = {};
        % Check input frequency bounds
        if any(fB <= 0) || fB(1) >= fB(2)
            bst_report('error','Invalid Frequency range');
            return
        end
        fMask = bst_round(inputFile.Freqs,1) >= fB(1) & inputFile.Freqs <= fB(2);
        fs = inputFile.Freqs(fMask);
        spec = log10(squeeze(inputFile.TF(:,1,fMask)));
        if any(fs == 0) % Model cannot handle 0 Hz input
            bst_report('error','Frequency range cannot include 0 Hz');
            return
        end
        % Initalize FOOOF structs
        fg(size(spec,1)) = struct('FOOOF',[]);
        for chan = 1:size(spec,1)
            bst_progress('set', bst_round(chan / size(spec,1),2) * 100);
            % Fit aperiodic
            aperiodic_pars = robust_ap_fit(fs,spec(chan,:),am);
            % Remove aperiodic
            flat_spec = flatten_spectrum(fs,spec(chan,:),aperiodic_pars,am);
            % Fit peaks
            [peak_pars, pti] = fit_peaks(fs,flat_spec,maxp,pet,minph,pwl/2,prt,pt,gw);
            % Refit aperiodic
            aperiodic = spec(chan,:);
            if strcmp(pti,'gaussian')
                for peak = 1:size(peak_pars,1)
                    aperiodic = aperiodic - gaussian_function(fs,peak_pars(peak,1),...
                        peak_pars(peak,2),peak_pars(peak,3));
                end
            elseif strcmp(pti,'cauchy')
                for peak = 1:size(peak_pars,1)
                    aperiodic = aperiodic - cauchy_function(fs,peak_pars(peak,1),...
                        peak_pars(peak,2),peak_pars(peak,3));
                end
            end
            aperiodic_pars = simple_ap_fit(fs,aperiodic,am);
            % Generate model fit
            ap_fit = gen_aperiodic(fs,aperiodic_pars,am);
            model_fit = ap_fit;
            for peak = 1:size(peak_pars,1)
                model_fit = model_fit + gaussian_function(fs,peak_pars(peak,1),...
                    peak_pars(peak,2),peak_pars(peak,3));
            end
            % Calculate model error
            MSE = sum((spec(chan,:) - model_fit).^2)/length(model_fit);
            rsq_tmp = corrcoef(spec(chan,:),model_fit).^2;
            % Return FOOOF results
            fg(chan).FOOOF = struct(...
                'aperiodic_params', aperiodic_pars,...
                'peak_params',      peak_pars,...
                'peak_types',       pti,...
                'ap_fit',           10.^ap_fit,...
                'fooofed_spectrum', 10.^model_fit,...
                'peak_fit',         10.^(model_fit-ap_fit),...
                'error',            MSE,...
                'r_squared',        rsq_tmp(2));
        end
        % Return FOOOF settings
        fp = struct('freq_range',           fB,...
                    'peak_type',            pts,...
                    'peak_width_limits',    pwl,...
                    'max_peaks',            maxp,...
                    'min_peak_height',      minph,...
                    'peak_threshold',       pet,...
                    'proximity_threshold',  prt,...
                    'aperiodic_mode',       ams,...
                    'guess_weight',         gws);
        % Save file
        [tmp, iOutputStudy] = bst_process('GetOutputStudy', sProcess, sInputs(iP));
        OutputFile{end+1} = SaveFile(inputFile, fp, fs, fg, iOutputStudy);
    end

end

%% ===== PYTHON FOOOF =====
function OutputFile = FOOOF_python(sProcess, sInputs, fB, pwl, maxp, minph, pet, am)
    switch am
        case 1,     ams = 'fixed';
        case 2,     ams = 'knee';
    end
    % set options
    settings = struct('peak_width_limits' ,pwl,'max_n_peaks', maxp,...
        'min_peak_height', minph,'peak_threshold', pet,'aperiodic_mode',...
        ams,'verbose',0); 
    rm = 1; % Always return model
    for iP = 1:length(sInputs)
        bst_progress('text',['Standby: FOOOFing spectrum ' num2str(iP) ' of ' num2str(length(sInputs))]);
        clear fg
        inputFile = in_bst_timefreq(sInputs(iP).FileName);
        % Initialize returned list of files
        OutputFile = {};
        % Check input frequency bounds
        if any(fB <= 0) || fB(1) >= fB(2)  
            bst_report('error','Invalid Frequency range');
            return
        end
        fs = inputFile.Freqs;
        % Preallocate space for FOOOF models
        fg(size(inputFile.TF,1)) = struct('FOOOF',[]);
        % Iterate across channels
        for chan = 1:size(inputFile.TF,1)
            bst_progress('set', bst_round(chan / size(inputFile.TF,1),2) * 100);
            % Run FOOOF on a single channel
            fr = fooof_py(fs',squeeze(inputFile.TF(chan,1,:))',fB,settings,rm);
            % Fix FOOOF error (Python and MATLAB give different values)
            fr.error = sum((fr.power_spectrum-fr.fooofed_spectrum).^2)/length(fr.freqs);
            % Fix FOOOF r_squared (Python and MATLAB give different values)
            rsq_tmp = corrcoef(fr.power_spectrum,fr.fooofed_spectrum).^2;
            fr.r_squared = rsq_tmp(2);
            % Only save one instance of frequencies (saves space)
            if ~exist('frqs','var')
                frqs = fr.freqs;
            end
            fr = rmfield(fr,'freqs');
            % Adjust data to raw power for Brainstorm
            fr.peak_fit = 10.^(fr.fooofed_spectrum - fr.ap_fit);
            fr.power_spectrum = 10.^fr.power_spectrum;
            fr.fooofed_spectrum = 10.^fr.fooofed_spectrum;
            fr.ap_fit = 10.^fr.ap_fit;
            % Return FOOOF model
            fg(chan).FOOOF = fr;
        end
        fp = struct('freq_range',           fB,...
                    'peak_width_limits',    pwl,...
                    'max_peaks',            maxp,...
                    'min_peak_height',      minph,...
                    'peak_threshold',       pet,...
                    'aperiodic_mode',       ams);  
        
        [tmp, iOutputStudy] = bst_process('GetOutputStudy', sProcess, sInputs(iP));
        OutputFile{end+1} = SaveFile(inputFile, fp, frqs, fg, iOutputStudy);
    end

end

%% ===== SAVE FILE =====
function NewFile = SaveFile(inputFile, FOOOF_params, FOOOF_freqs, FOOOF_group, iOutputStudy)

    % ===== PREPARE OUTPUT STRUCTURE =====
    % Create file structure
    FileMat = inputFile;
    FileMat.FOOOF           = struct('FOOOF_options',FOOOF_params,...
        'FOOOF_freqs', FOOOF_freqs, 'FOOOF_data', FOOOF_group);
    % Comment: Add FOOOF
    if ~isempty(strfind(FileMat.Comment, 'PSD:'))
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

function ys = cauchy_function(xs, ctr, hgt, gam)
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

    ys = hgt./(1+((xs-ctr)/gam).^2);

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
        perc_thresh = bst_prctile(flatspec, 2.5);
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

function [model_params,pti] = fit_peaks(freqs, flat_iter, max_n_peaks, peak_threshold, min_peak_height, gauss_std_limits, proxThresh, pt, guess_weight)
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
%         peak_threshold : double
%             Threshold (in standard deviations) to detect a peak
%         min_peak_height : double
%             Minimum height of a peak (in log10)
%         gauss_std_limits : 1 x 2 double
%             Limits to gaussian standard deviation when detecting a peak
%         proxThresh : double
%             Minimum distance between two peaks, in st. dev. of peak
%         guess_weight : int
%             Parameter to weigh initial estimates during optimization
%
%         Returns
%         -------
%         gaussian_params : 2d array
%             Parameters that define the gaussian fit(s).
%             Each row is a gaussian, as [mean, height, standard deviation].
    switch pt 
        case 1 % gaussian only
            pti = 'gaussian'; % Identify peaks as gaussian
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
            guess_params(guess_params(:,1) == 0,:) = [];

            % Check peaks based on edges, and on overlap
            % Drop any that violate requirements.
            guess_params = drop_peak_cf(guess_params, 1, [min(freqs) max(freqs)]);
            guess_params = drop_peak_overlap(guess_params, proxThresh);

            % If there are peak guesses, fit the peaks, and sort results.
            if ~isempty(guess_params)
                model_params = fit_peak_guess(guess_params, freqs, flat_spec, 1, guess_weight);
            else
                model_params = zeros(1, 3);
            end
            
        case 2 % cauchy only
            pti = 'cauchy'; % Identify peaks as cauchy
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
                ri_ind = length(flat_iter) - sum(flat_iter(max_ind:end) <= half_height);
                short_side = min(abs([le_ind,ri_ind]-max_ind));

                % Estimate gamma from FWHM. Calculate FWHM, converting to Hz, get guess std from FWHM
                fwhm = short_side * 2 * (freqs(2)-freqs(1));
                guess_gamma = fwhm/2;
                % Check that guess gamma isn't outside preset gamma limits; restrict if so.
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
                peak_cauchy = cauchy_function(freqs, guess_freq(1), guess_height, guess_gamma);
                flat_iter = flat_iter - peak_cauchy;

            end
            guess_params(guess_params(:,1) == 0,:) = [];
            guess_params = drop_peak_cf(guess_params, 1, [min(freqs) max(freqs)]);
            guess_params = drop_peak_overlap(guess_params, proxThresh);

            % If there are peak guesses, fit the peaks, and sort results.
            if ~isempty(guess_params)
                model_params = fit_peak_guess(guess_params, freqs, flat_spec, 2, guess_weight);
            else
                model_params = zeros(1, 3);
            end
        case 3 % best of both: model both fits and compare error, save best
            % Gaussian Fit
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
                ri_ind = length(flat_iter) - sum(flat_iter(max_ind:end) <= half_height);
                short_side = min(abs([le_ind,ri_ind]-max_ind));
                fwhm = short_side * 2 * (freqs(2)-freqs(1));
                guess_std = fwhm / (2 * sqrt(2 * log(2)));
                if guess_std < gauss_std_limits(1)
                    guess_std = gauss_std_limits(1);
                end
                if guess_std > gauss_std_limits(2)
                    guess_std = gauss_std_limits(2);
                end
                guess_params(guess,:) = [guess_freq, guess_height, guess_std];
                peak_gauss = gaussian_function(freqs, guess_freq, guess_height, guess_std);
                flat_iter = flat_iter - peak_gauss;
            end
            guess_params(guess_params(:,1) == 0,:) = [];
            guess_params = drop_peak_cf(guess_params, 1, [min(freqs) max(freqs)]);
            guess_params = drop_peak_overlap(guess_params, proxThresh);
            if ~isempty(guess_params)
                gauss_params = fit_peak_guess(guess_params, freqs, flat_spec, 1, guess_weight);
                flat_gauss = zeros(size(freqs));
                for peak = 1:size(gauss_params,1)
                    flat_gauss =  flat_gauss + gaussian_function(freqs,gauss_params(peak,1),...
                        gauss_params(peak,2),gauss_params(peak,3));
                end
                error_gauss = sum((flat_gauss-flat_spec).^2);
            else
                gauss_params = zeros(1, 3); error_gauss = 1E10;
            end
            
            % Cauchy Fit
            guess_params = zeros(max_n_peaks, 3);
            flat_iter = flat_spec;
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
                ri_ind = length(flat_iter) - sum(flat_iter(max_ind:end) <= half_height);
                short_side = min(abs([le_ind,ri_ind]-max_ind));
                fwhm = short_side * 2 * (freqs(2)-freqs(1));
                guess_gamma = fwhm/2;
                if guess_gamma < gauss_std_limits(1)
                    guess_gamma = gauss_std_limits(1);
                end
                if guess_gamma > gauss_std_limits(2)
                    guess_gamma = gauss_std_limits(2);
                end
                guess_params(guess,:) = [guess_freq(1), guess_height, guess_gamma];
                peak_cauchy = cauchy_function(freqs, guess_freq(1), guess_height, guess_gamma);
                flat_iter = flat_iter - peak_cauchy;
            end
            guess_params(guess_params(:,1) == 0,:) = [];
            guess_params = drop_peak_cf(guess_params, 1, [min(freqs) max(freqs)]);
            guess_params = drop_peak_overlap(guess_params, proxThresh);
            if ~isempty(guess_params)
                cauchy_params = fit_peak_guess(guess_params, freqs, flat_spec, 2, guess_weight);
                flat_cauchy = zeros(size(freqs));
                for peak = 1:size(cauchy_params,1)
                    flat_cauchy =  flat_cauchy + cauchy_function(freqs,cauchy_params(peak,1),...
                        cauchy_params(peak,2),cauchy_params(peak,3));
                end
                error_cauchy = sum((flat_cauchy-flat_spec).^2);
            else
                cauchy_params = zeros(1, 3); error_cauchy = 1E10;
            end
            % Save least-error model
                if min([error_gauss,error_cauchy]) == error_gauss
                    model_params = gauss_params;
                    pti = 'gaussian';
                else
                    model_params = cauchy_params;
                    pti = 'cauchy';
                end
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

function  model_params = fit_peak_guess(guess, freqs, flat_spec, fit_type, guess_weight)
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

    options = optimset('Display', 'off', 'TolX', 1e-6, 'TolFun', 1e-8, ...
        'MaxFunEvals', 5000, 'MaxIter', 5000);

    model_params = fminsearch(@error_model,...
        guess, options, freqs, flat_spec, fit_type, guess, guess_weight);

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

function err = error_model(params, xVals, yVals, fit_type, guess, guess_weight)
% error_gaussian
% Calculates error between data and a gaussian function, for use by fminsearch
% Params        - parameter vector (ampltude, mean, standard deviation)
% xVals         - values of independent variable
% yVals         - values of dependent variable (data points) at each of xVals
% guess         - initial estimates of parameter values
% guess_weight  - weight placed on initial estimates

%     m         = params(:,1);
%     amp       = params(:,2);
%     'stdev'   = params(:,3);

    fitted_vals = 0;

    for set = 1:size(params,1)
        if      fit_type == 1 % Gaussian model
            fitted_vals = fitted_vals + gaussian_function(xVals, ...
                params(set,1), params(set,2), params(set,3));
        elseif  fit_type == 2 % Cauchy model
            fitted_vals = fitted_vals + cauchy_function(xVals, ...
                params(set,1), params(set,2), params(set,3));
        end
    end
    switch guess_weight
        case 1
            err = sum((yVals - fitted_vals).^2);
        case 2 % Add small weight to deviations from guess m and amp
            err = sum((yVals - fitted_vals).^2) + ...
                 1E2*sum((params(:,1)-guess(:,1)).^2) + ...
                 1E2*sum((params(:,2)-guess(:,2)).^2);
        case 3 % Add large weight to deviations from guess m and amp
            err = sum((yVals - fitted_vals).^2) + ...
                 1E7*sum((params(:,1)-guess(:,1)).^2) + ...
                 1E7*sum((params(:,2)-guess(:,2)).^2);
    end
end
%% ===== FOOOF_py =====
function fooof_results = fooof_py(freqs, power_spectrum, f_range, settings, return_model)
% fooof_py() - Fit the FOOOF model on a neural power spectrum.
%
% Usage:
%   >> fooof_results = fooof_py(freqs, power_spectrum, f_range, settings, return_model);
%
% Inputs:
%   freqs           = row vector of frequency values
%   power_spectrum  = row vector of power values
%   f_range         = fitting range (Hz)
%   settings        = fooof model settings, in a struct, including:
%       settings.peak_width_limts
%       settings.max_n_peaks
%       settings.min_peak_height
%       settings.peak_threshold
%       settings.aperiodic_mode
%       settings.verbose
%   return_model    = boolean of whether to return the FOOOF model fit, optional
%
% Outputs:
%   fooof_results   = fooof model ouputs, in a struct, including:
%       fooof_results.aperiodic_params
%       fooof_results.peak_params
%       fooof_results.gaussian_params
%       fooof_results.error
%       fooof_results.r_squared
%       if return_model is true, it also includes:
%            fooof_results.freqs
%            fooof_results.power_spectrum
%            fooof_results.fooofed_spectrum
%            fooof_results.ap_fit
%
% Notes
%   Not all settings need to be defined by the user.
%     Any settings that are not provided are set to default values.
%     To run with all defaults, input settings as an empty struct.
    
    % Check settings - get defaults for those not provided
    settings = fooof_check_settings(settings);
    % Import python modules
    py.importlib.import_module('fooof');
    py.importlib.import_module('numpy');
    py.importlib.import_module('scipy');
    % Convert inputs
    freqs = py.numpy.array(freqs);
    power_spectrum = py.numpy.array(power_spectrum);
    f_range = py.list(f_range);

    % Initialize FOOOF object
    fm = py.fooof.FOOOF(settings.peak_width_limits, ...
                        settings.max_n_peaks, ...
                        settings.min_peak_height, ...
                        settings.peak_threshold, ...
                        settings.aperiodic_mode, ...
                        settings.verbose);

    % Run FOOOF fit
    fm.fit(freqs, power_spectrum, f_range);

    % Extract outputs
    fooof_results = fm.get_results();
    fooof_results = fooof_unpack_results(fooof_results);
    
    % Re-calculating r-squared
    %   r_squared doesn't seem to get computed properly (in NaN).
    %   It is unclear why this happens, other than the error can be traced
    %   back to the internal call to `np.cov`, and fails when this function
    %   gets two arrays as input.
    %   Therefore, we can simply recalculate r-squared
    coefs = corrcoef(double(py.array.array('d', fm.power_spectrum)), ...
                     double(py.array.array('d', fm.fooofed_spectrum_)));
    fooof_results.r_squared = coefs(2);
    
    % Also return the actual model fit, if requested
    %   This will default to not return model, if variable not set
    if exist('return_model', 'var') && return_model
        % Get the model, and add outputs to fooof_results
        model_out = fooof_get_model(fm);
        for field = fieldnames(model_out)'
            fooof_results.(field{1}) = model_out.(field{1});
        end
    end
end

function model_fit = fooof_get_model(fm)
% fooof_get_model() - Return the model fit values from a FOOOF object
%
% Usage:
%   >> model_fit = fooof_get_model(fm)
%
% Inputs:
%   fm              = FOOOF object
%
% Outputs:
%   model_fit       = model results, in  a struct, including:
%       model_fit.freqs
%       model_fit.power_spectrum
%       model_fit.fooofed_spectrum
%       model_fit.ap_fit
%
% Notes
%   This function is mostly an internal function.
%     It can be called directly by the user if you are interacting with FOOOF objects directly.
    model_fit = struct();

    model_fit.freqs = double(py.array.array('d',fm.freqs));
    model_fit.power_spectrum = double(py.array.array('d', fm.power_spectrum));
    model_fit.fooofed_spectrum = double(py.array.array('d', fm.fooofed_spectrum_));
    model_fit.ap_fit = double(py.array.array('d', py.getattr(fm, '_ap_fit')));
end

function results_out = fooof_unpack_results(results_in)
% fooof_unpack_results() - Extract model fit results from FOOOFResults.
%
% Usage:
%   >> results_out = fooof_unpack_results(results_in);
%
% Inputs:
%   fooof_results   = FOOOFResults object
%
% Outputs:
%   results_out     = fooof model results, in a struct, including:
%       results_out.aperiodic_params
%       results_out.peak_params
%       results_out.gaussian_params
%       results_out.error
%       results_out.r_squared
%
% Notes
%   This function is mostly an internal function.
%     It can be called directly by the user if you are interacting with FOOOF objects directly.
    results_out = struct();

    results_out.aperiodic_params = ...
        double(py.array.array('d', results_in.aperiodic_params));

    temp = double(py.array.array('d', results_in.peak_params.ravel));
    results_out.peak_params = ...
        transpose(reshape(temp, 3, length(temp) / 3));

    temp = double(py.array.array('d', results_in.gaussian_params.ravel));
    results_out.gaussian_params = ...
        transpose(reshape(temp, 3, length(temp) / 3));

    results_out.error = ...
        double(py.array.array('d', py.numpy.nditer(results_in.error)));

    % Note: r_squared gets recalculated, so doesn't need type casting
    %   Just in case, the code for type casting is:
    %results_out.r_squared = ...
    %    double(py.array.array('d', py.numpy.nditer(results_in.r_squared)));    
end

function settings = fooof_check_settings(settings)
% fooof_check_settings() - Check a struct of settings for the FOOOF model.
%
% Usage:
%  >> settings = fooof_check_settings(settings)
%
% Inputs:
%   settings        = struct, can optionally include:
%       settings.peak_width_limts
%       settings.max_n_peaks
%       settings.min_peak_height
%       settings.peak_threshold
%       settings.aperiodic_mode
%       settings.verbose
%
% Outputs:
%   settings        = struct, with all settings defined:
%       settings.peak_width_limts
%       settings.max_n_peaks
%       settings.min_peak_height
%       settings.peak_threshold
%       settings.aperiodic_mode
%       settings.verbose
%
% Notes:
%   This is a helper function, probably not called directly by the user.
%   Any settings not specified are set to default values
    % Set defaults for all settings
    defaults = struct(...
        'peak_width_limits', [0.5, 12], ...
        'max_n_peaks', Inf, ...
        'min_peak_height', 0.0, ...
        'peak_threshold', 2.0, ...
        'aperiodic_mode', 'fixed', ...
        'verbose', true);

    % Overwrite any non-existent or nan settings with defaults
    for field = fieldnames(defaults)'
        if ~isfield(settings, field) || all(isnan(settings.(field{1})))
            settings.(field{1}) = defaults.(field{1});
        end
    end

end