function varargout = process_fooof_py(varargin)
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
    sProcess.Comment     = 'FOOOF_py';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Frequency';
    sProcess.Index       = 505;
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
    sProcess.options.minPeakHeight.Value   = {1,'Log-Power (dB/Hz)',1};
    % === PEAK THRESHOLD
    sProcess.options.peakThreshold.Comment = 'Peak threshold: ';
    sProcess.options.peakThreshold.Type    = 'value';
    sProcess.options.peakThreshold.Value   = {2,'stdev of noise',1};
    % === APERIODIC MODE
    sProcess.options.aperiodicMode.Comment = {'Fixed', 'Knee', 'Aperiodic Mode:'};
    sProcess.options.aperiodicMode.Type    = 'radio_line';
    sProcess.options.aperiodicMode.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== GET OPTIONS =====
function [freqBand, peakWidthLims, maxPeaks, minPeakHeight, peakThresh, aperMode] = GetOptions(sProcess)
    freqBand = sProcess.options.freqBand.Value{1};
    peakWidthLims = sProcess.options.peakWidthLimits.Value{1};
    maxPeaks = sProcess.options.maxPeaks.Value{1};
    minPeakHeight = sProcess.options.minPeakHeight.Value{1}/10; % convert from ln to log10
    peakThresh = sProcess.options.peakThreshold.Value{1};
    aperMode = sProcess.options.aperiodicMode.Value;
end

%% ===== RUN =====
function OutputFile = Run(sProcess, sInputs) %#ok<DEFNU>
    [fB, pwl, maxp, minph, pet, am] = GetOptions(sProcess);
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
            bst_progress('set', round(chan / size(inputFile.TF,1),2) * 100);
            % Run FOOOF on a single channel
            fr = fooof_py(fs',squeeze(inputFile.TF(chan,1,:))',fB,settings,rm);
            % Fix FOOOF error (Python and MATLAB give different values)
            fr.error = sum((fr.power_spectrum-fr.model_fit).^2)/length(fr.freqs);
            % Fix FOOOF r_squared (Python and MATLAB give different values)
            rsq_tmp = corrcoef(fr.power_spectrum,fr.model_fit).^2;
            fr.r_squared = rsq_tmp(2);
            % Return FOOOF model
            fg(chan).FOOOF = fr;
        end
        fp = struct('freq_range',           fB,...
                    'peak_width_limits',    pwl,...
                    'max_peaks',            maxp,...
                    'min_peak_height',      minph,...
                    'peak_threshold',       pet,...
                    'aperiodic_mode',       ams);
        [~, iOutputStudy] = bst_process('GetOutputStudy', sProcess, sInputs(iP));
        OutputFile{end+1} = SaveFile(inputFile, fp, fg, iOutputStudy);
    end
end

%% ===== SAVE FILE =====
function NewFile = SaveFile(inputFile, FOOOF_params, FOOOF_group, iOutputStudy)

    % ===== PREPARE OUTPUT STRUCTURE =====
    % Create file structure
    FileMat = inputFile;
    FileMat.FOOOF_params    = FOOOF_params;
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
