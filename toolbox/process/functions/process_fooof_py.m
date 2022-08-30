function varargout = process_fooof_py(varargin)
% PROCESS_FOOOF_PY: Python calls of process_fooof.m

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
% Authors: Luc Wilson, Francois Tadel, 2020

eval(macro_method);
end


%% ===== PYTHON FOOOF =====
function [fs, fg] = FOOOF_python(TF, Freqs, opt)
    % Import python modules
    modules = py.sys.modules;
    modules = string(cell(py.list(modules.keys())));
    % First, check if any modules are already imported
    if ~any(strcmp('fooof',modules)), py.importlib.import_module('fooof'); end
    if ~any(strcmp('scipy',modules)), py.importlib.import_module('scipy'); end
    if ~any(strcmp('numpy',modules)), py.importlib.import_module('numpy'); end
    
    % Initalize FOOOF structs
    fg = repmat(struct('FOOOF',[]), 1, size(TF,1));
    % Iterate across channels
    for chan = 1:size(TF,1)
        bst_progress('set', bst_round(chan / size(TF,1),2) * 100);
        % Run FOOOF on a single channel
        fr = fooof_py(Freqs', squeeze(TF(chan,1,:))', opt.freq_range, opt);
        % Fix FOOOF error (Python and MATLAB give different values)
        fr.error = sum((fr.power_spectrum-fr.fooofed_spectrum).^2)/length(fr.freqs);
        % Fix FOOOF r_squared (Python and MATLAB give different values)
        rsq_tmp = corrcoef(fr.power_spectrum,fr.fooofed_spectrum).^2;
        fr.r_squared = rsq_tmp(2);
        % Only save one instance of frequencies (saves space)
        fr = rmfield(fr,'freqs');
        % Adjust data to raw power for Brainstorm
        fr.peak_fit = 10.^(fr.fooofed_spectrum - fr.ap_fit);
        fr.power_spectrum = 10.^fr.power_spectrum;
        fr.fooofed_spectrum = 10.^fr.fooofed_spectrum;
        fr.ap_fit = 10.^fr.ap_fit;
        % Return FOOOF model
        fg(chan).FOOOF = fr;
    end
    fs = Freqs(Freqs >= opt.freq_range(1) & Freqs <= opt.freq_range(2));
end


%% ===== FOOOF_py =====
function fooof_results = fooof_py(freqs, power_spectrum, f_range, settings)
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
%       settings.max_peaks
%       settings.min_peak_height
%       settings.peak_threshold
%       settings.aperiodic_mode
%       settings.verbose
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
%   Any settings that are not provided are set to default values.
%   To run with all defaults, input settings as an empty struct.
% Author: Tom Donoghue

    % Convert inputs
    freqs = py.numpy.array(freqs);
    power_spectrum = py.numpy.array(power_spectrum);
    f_range = py.list(f_range);

    % Initialize FOOOF object
    fm = py.fooof.FOOOF(settings.peak_width_limits, ...
                        settings.max_peaks, ...
                        settings.min_peak_height, ...
                        settings.peak_threshold, ...
                        settings.aperiodic_mode, ...
                        settings.verbose);

    % Run FOOOF fit
    fm.fit(freqs, power_spectrum, f_range);

    % Extract outputs
    fooof_results = fm.get_results();
    fooof_results = fooof_unpack_results(fooof_results);
    
    %   Re-calculating r-squared
    %   r_squared doesn't seem to get computed properly (in NaN).
    %   It is unclear why this happens, other than the error can be traced
    %   back to the internal call to `np.cov`, and fails when this function
    %   gets two arrays as input.
    %   Therefore, we can simply recalculate r-squared
    coefs = corrcoef(double(py.array.array('d', fm.power_spectrum)), ...
                     double(py.array.array('d', fm.fooofed_spectrum_)));
    fooof_results.r_squared = coefs(2);
    
    % Get the model, and add outputs to fooof_results
    model_out = fooof_get_model(fm);
    for field = fieldnames(model_out)'
        fooof_results.(field{1}) = model_out.(field{1});
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
%   It can be called directly by the user if you are interacting with FOOOF objects directly.
% Author: Tom Donoghue
%
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
%   It can be called directly by the user if you are interacting with FOOOF objects directly.
% Author: Tom Donoghue

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

