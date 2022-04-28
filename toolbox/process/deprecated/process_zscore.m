function varargout = process_zscore( varargin )
% PROCESS_ZSCORE: Compute Z-Score for a matrix A (normalization respect to a baseline).
%
% DESCRIPTION:  For each channel:
%     1) Compute mean m and variance v for baseline
%     2) For each time sample, subtract m and divide by v
                        
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
% Authors: Francois Tadel, 2010-2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Z-score normalization [DEPRECATED]';
    sProcess.FileTag     = 'zscore';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 0;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/SourceEstimation#Z-score';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Default values for some options
    sProcess.isSourceAbsolute = 0;
    sProcess.processDim       = 1;    % Process channel by channel

    % Definition of the options
    sProcess.options.description.Comment = ['For each signal in input:<BR>' ...
                                            '1) Compute mean <I>m</I> and variance <I>v</I> for the baseline<BR>' ...
                                            '2) For each time sample, subtract <I>m</I> and divide by <I>v</I><BR>' ...
                                            'Z = (Data - <I>m</I>) / <I>v</I><BR><BR>'];
    sProcess.options.description.Type    = 'label';
    % === Baseline time window
    sProcess.options.baseline.Comment = 'Baseline:';
    sProcess.options.baseline.Type    = 'baseline';
    sProcess.options.baseline.Value   = [];
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data'};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Get time window
    if isfield(sProcess.options, 'baseline') && isfield(sProcess.options.baseline, 'Value') && iscell(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value{1})
        Time = sProcess.options.baseline.Value{1};
    else
        Time = [];
    end
    % Add time window to the comment
    if isempty(Time)
        Comment = 'Z-score normalization: [All file]';
    elseif any(abs(Time) > 2)
        Comment = sprintf('Z-score normalization: [%1.3fs,%1.3fs]', Time(1), Time(2));
    else
        Comment = sprintf('Z-score normalization: [%dms,%dms]', round(Time(1)*1000), round(Time(2)*1000));
    end
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Get options
    if isfield(sProcess.options, 'baseline') && isfield(sProcess.options.baseline, 'Value') && iscell(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value{1})
        BaselineBounds = sProcess.options.baseline.Value{1};
    else
        BaselineBounds = [];
    end
    % Get baseline indices
    if ~isempty(BaselineBounds)
        iBaseline = panel_time('GetTimeIndices', sInput.TimeVector, sProcess.options.baseline.Value{1});
        if isempty(iBaseline)
            bst_report('Error', sProcess, [], 'Invalid baseline definition.');
            sInput = [];
            return;
        end
    % Get all file
    else
        iBaseline = 1:size(sInput.A,2);
    end
    % Compute zscore
    sInput.A = Compute(sInput.A, iBaseline);
    % Change DataType
    if ~strcmpi(sInput.FileType, 'timefreq')
        sInput.DataType = 'zscore';
    end
    % Default colormap
    if strcmpi(sInput.FileType, 'results')
        sInput.ColormapType = 'stat1';
        sInput.Function     = 'zscore';
    else
        sInput.ColormapType = 'stat2';
    end
    % Do not keep the Std field in the output
    if isfield(sInput, 'Std') && ~isempty(sInput.Std)
        sInput.Std = [];
    end
end


%% ===== COMPUTE =====
function A = Compute(A, iBaseline)
    disp('BST> process_zscore.m is deprecated, use "Standardize > Baseline normalization" instead.');
    % Calculate mean and standard deviation
    [meanBaseline, stdBaseline] = ComputeStat(A(:, iBaseline,:));
    % Compute zscore
    A = bst_bsxfun(@minus, A, meanBaseline);
    A = bst_bsxfun(@rdivide, A, stdBaseline);
end

function [meanBaseline, stdBaseline] = ComputeStat(A)
    % Compute baseline statistics
    stdBaseline  = std(A, 0, 2);
    meanBaseline = mean(A, 2);
    % Remove null variance values
    stdBaseline(stdBaseline == 0) = 1e-12;
end


