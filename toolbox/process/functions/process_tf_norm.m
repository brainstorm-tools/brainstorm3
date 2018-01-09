function varargout = process_tf_norm( varargin )
% PROCESS_TF_NORM: Normalize frequency and time-frequency results.
%
% USAGE:          sInput = process_tf_norm('Run', sProcess, sInput)
%         [TF, errorMsg] = process_tf_norm('Compute', TF, Measure, Freqs, Method)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2014

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
    sProcess.options.normalize.Comment = {'1/f compensation (multiple by frequency)', 'Relative power (divide by total power)'; ...
                                          'multiply', 'relative'};
    sProcess.options.normalize.Type    = 'radio_label';
    sProcess.options.normalize.Value   = 'multiply';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== GET FILE TAG =====
function fileTag = GetFileTag(sProcess)
    fileTag = sProcess.options.normalize.Value;
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Normalization method
    switch lower(sProcess.options.normalize.Value)
        case {1, 'multiply'},  Method = 'multiply';
        case {2, 'relative'},  Method = 'relative';
    end
    % Load the frequency and measure information
    TfMat = in_bst_timefreq(sInput.FileName, 0, 'Measure', 'Freqs');
    % Compute normalization
    [sInput.A, errorMsg] = Compute(sInput.A, TfMat.Measure, TfMat.Freqs, Method);
    % Error management
    if ~isempty(errorMsg)
        bst_report('Error', sProcess, sInput, errorMsg);
        sInput = [];
    end
    % Do not keep the Std field in the output
    if isfield(sInput, 'Std') && ~isempty(sInput.Std)
        sInput.Std = [];
    end
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
    switch (Method)
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
            % If processing power: square the frequency
            if strcmpi(Measure, 'power')
                Factor = Factor .^ 2;
            end
            % Reshape to have the scaling values in the third dimension
            Factor = reshape(Factor, 1, 1, []);
        case 'relative'
            % If measure is not power/magnitude/log
            if ~ismember(Measure, {'power', 'magnitude'})
                errorMsg = ['Values with measure "' Measure '" cannot be normalized with this process.'];
                TF = [];
                return;
            end
            % Divide by the total power
            Factor = 1 ./ sum(TF,3);
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


