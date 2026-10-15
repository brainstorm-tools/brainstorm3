function varargout = process_detrend_emd( varargin )
% PROCESS_DETREND_EMD: Remove a non-linear trend in a signal with EMD
%
% This process:
%   1) Decomposes each channel into intrinsic mode functions using EMD
%   2) Estimates the characteristic frequency of each IMF
%   3) Keeps only modes above the selected cutoff frequency
%
% USAGE:
%   OutputFiles = process_detrend_emd('Run', sProcess, sInputs)

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
% Authors: Kenneth N. Taylor, 2020
%          John C. Mosher, 2020
%          Chinmay Chinara, 2026

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Remove non-linear trend with EMD';
    sProcess.FileTag     = 'emd';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Pre-process';
    sProcess.Index       = 61.5;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/FastGraph';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data', 'results', 'matrix'};
    sProcess.OutputTypes = {'raw', 'data', 'results', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Default values for some options
    sProcess.processDim  = 1;    % Process channel by channel

    % Definition of the options
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data', 'raw'};
    % === EMD cutoff frequency
    sProcess.options.emdcutoff.Comment = 'EMD cutoff frequency: ';
    sProcess.options.emdcutoff.Type    = 'value';
    sProcess.options.emdcutoff.Value   = {2, 'Hz', 2};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Get options
    if isfield(sProcess.options, 'emdcutoff') && isfield(sProcess.options.emdcutoff, 'Value') && iscell(sProcess.options.emdcutoff.Value) && ~isempty(sProcess.options.emdcutoff.Value)
        CutoffFreq = sProcess.options.emdcutoff.Value{1};
    else
        CutoffFreq = [];
    end
    if isempty(CutoffFreq) || isequal(CutoffFreq, 0)
        bst_report('Error', sProcess, [], 'Invalid cutoff frequency value.');
        sInput = [];
        return
    end

    % Sampling frequency
    Fs = 1 / mean(diff(sInput.TimeVector));

    % Apply EMD-based filtering to suppress drift
    for iChan = 1:size(sInput.A, 1)
        % Decompose signal into intrinsic mode functions
        imf = emd(sInput.A(iChan, :));
        % Estimate the characteristic frequency of each mode
        modeFreq = ImfStats(imf, Fs);
        % Keep only modes above cutoff to remove drift
        sInput.A(iChan, :) = sum(imf(:, modeFreq > CutoffFreq), 2)';
    end

    % Add history comment
    sInput.HistoryComment = sprintf('Removed non-linear trend with EMD: cutoff frequency = %.3f Hz', CutoffFreq);

    % Do not keep the Std field in the output
    if isfield(sInput, 'Std') && ~isempty(sInput.Std)
        sInput.Std = [];
    end
end


%% ===== IMF MODE STATISTICS =====
function modeFreq = ImfStats(imf, Fs)
    % IMF matrix is expected as [time x modes]
    nTime = size(imf, 1);
    % Remove linear trend before sign-change counting
    imfDetrended = detrend(imf);
    % Count zero crossings / sign changes
    nSignChanges = sum(abs(diff(sign(imfDetrended))) > 0, 1);
    % Convert sign changes to approximate frequency
    durationSec = nTime / Fs;
    modeFreq = nSignChanges ./ (2 * durationSec);
end