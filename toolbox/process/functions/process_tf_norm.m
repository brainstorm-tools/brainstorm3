function varargout = process_tf_norm( varargin )
% PROCESS_TF_NORM: Normalize frequency and time-frequency results.
%
% USAGE:          sInput = process_tf_norm('Run', sProcess, sInput)
%         [TF, errorMsg] = process_tf_norm('Compute', TF, Measure, Freqs, Method)

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
% Authors: Francois Tadel, 2014-2022
%          Marc Lalancette, 2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Spectrum normalization';
    sProcess.FileTag     = @GetFileTag;
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 415;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Options: Normalization
    sProcess.options.normalize.Comment = {'1/f compensation (multiply power by frequency)', '<FONT color="#a0a0a0">1/f<SUP>2</SUP> compensation (default before Nov 2020)</FONT>', 'Relative power (divide by total power)'; ...
                                          'multiply2020', 'multiply', 'relative2020'};
    sProcess.options.normalize.Type    = 'radio_label';
    sProcess.options.normalize.Value   = 'multiply2020';
    % Extra label
    sProcess.options.warning.Comment = ['<BR><I><FONT color="#a0a0a0">Warning: The total power is computed as the sum of all the values.<BR>' ...
                                        'With overlapping frequency bands, e.g. 8-12Hz 8-10Hz 10-12Hz,<BR>' ...
                                        'parts of the spectrum would be added twice to the total power.</FONT></I>'];
    sProcess.options.warning.Type    = 'label';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== GET FILE TAG =====
function fileTag = GetFileTag(sProcess)
    fileTag = sProcess.options.normalize.Value;
    % Remove '2020'
    fileTag = strrep(fileTag, '2020', '');
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Normalization method
    switch lower(sProcess.options.normalize.Value)
        case {1, 'multiply'},  Method = 'multiply';
        case {2, 'relative'},  Method = 'relative';
        otherwise
            Method = lower(sProcess.options.normalize.Value);
    end
    % Check if normalization was already applied.
    if isfield(sInput, 'Options') && isfield(sInput.Options, 'Normalized') && ...
            ~isempty(sInput.Options.Normalized) && ~isequal(sInput.Options.Normalized, 'none')
        if isequal(sInput.Options.Normalized, Method)
            bst_report('Warning', sProcess, sInput, ['Skipping file, requested normalization ' Method ' already applied.']);
            return;
        else
            bst_report('Error', sProcess, sInput, ['Cannot apply multiple normalization methods to the same file. Requested: ' Method ', already applied: ' sInput.Options.Normalized '.']);
            return;
        end
    end
    % Load the frequency and measure information
    TfMat = in_bst_timefreq(sInput.FileName, 0, 'Measure', 'Freqs');
    % Compute normalization
    [sInput.A, errorMsg] = Compute(sInput.A, TfMat.Measure, TfMat.Freqs, Method);
    % Error management
    if ~isempty(errorMsg)
        if isempty(sInput.A)
            bst_report('Error', sProcess, sInput, errorMsg);
            sInput = [];
        else
            bst_report('Warning', sProcess, sInput, errorMsg);
        end
    end
    % Do not keep the Std field in the output
    if isfield(sInput, 'Std') && ~isempty(sInput.Std)
        sInput.Std = [];
    end
    % Save normalization info.
    sInput.Options.Normalized = Method;
end


%% ===== COMPUTE =====
function [TF, errorMsg] = Compute(TF, Measure, Freqs, Method)
    % Initialize returned values
    errorMsg = '';
%     % Error: Cannot process complex values
%     if ~isreal(TF)
%         errorMsg = 'Cannot normalize complex values. Please apply a measure first.';
%         TF = [];
%         return;
%     end
    % No frequency information available
    if isempty(Freqs) || isequal(Freqs, 0)
        errorMsg = 'No frequency information available';
        TF = [];
        return;
    end
    % Different normalization methods
    Factor = [];
    switch Method
        case 'none'
            % Nothing to do
        case 'multiply'
            % Frequency bins
            if isnumeric(Freqs)
                Factor = Freqs;
            % Frequency bands
            elseif iscell(Freqs)
                BandBounds = process_tf_bands('GetBounds', Freqs);
                Factor = mean(BandBounds,2);
            end
            % If processing power: 
            if strcmpi(Measure, 'power')
                Factor = Factor.^2;
            end
            % Reshape to have the scaling values in the third dimension
            Factor = reshape(Factor, 1, 1, []);
        case 'relative'
            % Divide by the total (power or magnitude)
            Factor = 1 ./ sum(TF,3);
            % If measure is not power/magnitude
            if ~ismember(lower(Measure), {'power', 'magnitude'})
                errorMsg = ['Values with measure "' Measure '" cannot be normalized with this process.'];
                TF = [];
                return;
            end
        case 'multiply2020'
            % Frequency bins
            if isnumeric(Freqs)
                Factor = Freqs;
            % Frequency bands
            elseif iscell(Freqs)
                BandBounds = process_tf_bands('GetBounds', Freqs);
                Factor = mean(BandBounds,2);
            end
            % If processing magnitude: 
            if strcmpi(Measure, 'magnitude')
                Factor = sqrt(Factor);
            end
            % Reshape to have the scaling values in the third dimension
            Factor = reshape(Factor, 1, 1, []);
        case 'relative2020'
            % Check if overlap between bands
            if iscell(Freqs)
                BandBounds = process_tf_bands('GetBounds', Freqs);
                for iBand = 1:size(BandBounds,1)
                    if any((BandBounds(iBand,1) > BandBounds(:,1)) & (BandBounds(iBand,1) < BandBounds(:,2))) || ...
                       any((BandBounds(iBand,2) > BandBounds(:,1)) & (BandBounds(iBand,2) < BandBounds(:,2)))
                        errorMsg = ['Some frequency bands in the input file are overlapping. Some parts of the spectrum are added multiple times to the total power, ' ...
                            'leading to a wrong estimation of the relative power. Consider computing the PSD/TF files with the sub-frequency bands only, and group them after normalization.'];
                        break;
                    end
                end
            end
            % Always sum total power (then sqrt for relative magnitude)
            switch Measure
                case 'power'
                    % Divide by the total power
                    Factor = 1 ./ sum(TF,3);
                case 'magnitude'
                    Factor = 1 ./ sqrt(sum(TF.^2,3));
                % If measure is not power/magnitude
                otherwise
                    errorMsg = ['Values with measure "' Measure '" cannot be normalized with this process.'];
                    TF = [];
                    return;
            end
        otherwise
            errorMsg = ['Invalid normalization method: ' Method];
            TF = [];
            return;
    end
    % Apply multiplication factor
    if ~isempty(Factor)
        TF = bst_bsxfun(@times, TF, Factor);
    end
end


