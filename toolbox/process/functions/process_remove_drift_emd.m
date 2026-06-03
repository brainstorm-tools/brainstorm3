function varargout = process_remove_drift_emd(varargin)
% PROCESS_REMOVE_DRIFT_EMD: Remove drift using Empirical Mode Decomposition (EMD)
%
% This process:
%   1) Decomposes each channel into intrinsic mode functions using EMD
%   2) Estimates the characteristic frequency of each IMF
%   3) Keeps only modes above the selected cutoff frequency
%
% USAGE:
%   OutputFiles = process_remove_drift_emd('Run', sProcess, sInputs)

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
sProcess.Comment     = 'Remove drift using EMD';
sProcess.FileTag     = 'emd';
sProcess.Category    = 'Filter';
sProcess.SubGroup    = 'FAST graph';
sProcess.Index       = 1302;
sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/FastGraph';
% Definition of the input accepted by this process
sProcess.InputTypes  = {'data'};
sProcess.OutputTypes = {'data'};
sProcess.nInputs     = 1;
sProcess.nMinFiles   = 1;
% EMD cutoff frequency
sProcess.options.cutoff.Comment = 'EMD cutoff frequency: ';
sProcess.options.cutoff.Type    = 'value';
sProcess.options.cutoff.Value   = {2, 'Hz', 2};
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end

%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Get process option values
    CutoffFreq = sProcess.options.cutoff.Value{1};
    if CutoffFreq <= 0
        bst_report('Error', sProcess, [], 'EMD cutoff frequency must be positive.');
        return;
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
    sInput.HistoryComment = sprintf('Removed drift using EMD: cutoff frequency = %.3f Hz', CutoffFreq);
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