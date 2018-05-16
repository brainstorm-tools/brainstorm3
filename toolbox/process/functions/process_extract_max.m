function varargout = process_extract_max( varargin )
% PROCESS_EXTRACT_MAX: Find the maximum value in time (returns the latency or the peak values).

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
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
% Authors: Francois Tadel, 2016; Martin Cousineau, 2017

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Find maximum in time';
    sProcess.FileTag     = @GetFileTag;
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Extract';
    sProcess.Index       = 354;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    
    % Definition of the options
    % === TIME WINDOW
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data', 'raw'};
    % === METHOD
    sProcess.options.labelmethod.Comment = '<BR>What to detect:';
    sProcess.options.labelmethod.Type    = 'label';
    sProcess.options.method.Comment = {'Maximum amplitude  (positive or negative peak)', 'Maximum value  (positive peak)', 'Minimum value  (negative peak)'; ...
                                       'absmax', 'max', 'min'};
    sProcess.options.method.Type    = 'radio_label';
    sProcess.options.method.Value   = 'absmax';
    % === OUTPUT
    sProcess.options.labelout.Comment = '<BR>Value to save in the output file:';
    sProcess.options.labelout.Type    = 'label';
    sProcess.options.output.Comment = {'Peak amplitude  (for each signal separately)', 'Latency at the peak  (for each signal separately)', 'Global maximum  (other channels set to zero)'; ...
                                       'amplitude', 'latency', 'globalmax'};
    sProcess.options.output.Type    = 'radio_label';
    sProcess.options.output.Value   = 'amplitude';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Preprocess values to detect the correct peaks
    switch (sProcess.options.method.Value)
        case 'absmax',  Comment = 'Find maximum amplitude';
        case 'max',     Comment = 'Find maximum value';
        case 'min',     Comment = 'Find minimum value';
    end
    % Get time window
    Comment = [Comment, ': [', process_extract_time('GetTimeString', sProcess), ']'];
    % Absolute values 
    if isfield(sProcess.options, 'source_abs') && sProcess.options.source_abs.Value
        Comment = [Comment, ', abs'];
    end
    % Output
    if isequal(sProcess.options.output.Value, 'latency')
        Comment = [Comment, ', latency'];
    elseif isequal(sProcess.options.output.Value, 'globalmax')
        Comment = [Comment, ', global'];
    end
end

%% ===== GET FILE TAG =====
function fileTag = GetFileTag(sProcess)
    fileTag = sProcess.options.method.Value;
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Get options
    Output = sProcess.options.output.Value;
    Method = sProcess.options.method.Value;
    % Get time window
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value{1})
        iTime = panel_time('GetTimeIndices', sInput.TimeVector, sProcess.options.timewindow.Value{1});
    else
        iTime = 1:length(sInput.TimeVector);
    end
    if isempty(iTime)
        bst_report('Error', sProcess, [], 'Invalid time definition.');
        sInput = [];
        return;
    end
    
    % Preprocess values to detect the correct peaks
    minmaxFunc = @max;
    switch (Method)
        case 'absmax'
            sInput.A = abs(sInput.A);
        case 'max'
            % nothing to change
        case 'min'
            minmaxFunc = @min;
    end
    % Find maximum in time
    [MinMax, iMinMax] = minmaxFunc(sInput.A(:,iTime,:), [], 2);
    % Save the expected value
    switch (Output)
        case 'amplitude'
            sInput.A = MinMax;
            % Time vector: First and last time values
            sInput.TimeVector = [sInput.TimeVector(iTime(1)), sInput.TimeVector(iTime(end))];
            strMethod = '';
        case 'latency'
            sInput.A = reshape(sInput.TimeVector(iTime(iMinMax)), size(iMinMax));
            % Time vector: First and last time values
            sInput.TimeVector = [sInput.TimeVector(iTime(1)), sInput.TimeVector(iTime(end))];
            strMethod = ', latency';
            sInput.DisplayUnits = 'time';
        case 'globalmax'
            % Not supported for time-frequency files
            if strcmpi(sInput.FileType, 'timefreq')
                bst_report('Error', sProcess, [], 'The option "Global maximum" is not available for time-frequency files. Post this message on the forum if you would like to get this feature enabled.');
                return;
            end
            % Detect the maximum amplitude across signals
            [SigMax, iSigMax] = max(MinMax, [], 1);
            % Set all the other values to zero
            sInput.A = zeros(size(MinMax));
            sInput.A(iSigMax) = SigMax;
            % Time vector: Latency of the maximum
            T = sInput.TimeVector(2) - sInput.TimeVector(1);
            if (T > 0.100)
                T = 0.001;
            end
            sInput.TimeVector = sInput.TimeVector(iTime(iMinMax(iSigMax))) + [0,T];
            strMethod = ', global';
    end
    
    % Copy values to represent the time window
    sInput.A = [sInput.A, sInput.A];
    % Build file tag
    sInput.CommentTag = [Method '(' process_extract_time('GetTimeString',sProcess,sInput) strMethod ')'];
    % Change DataType
    if ~strcmpi(sInput.FileType, 'timefreq')
        sInput.DataType = Method;
    end
    % Do not keep the Std/TFmask fields in the output
    if isfield(sInput, 'Std') && ~isempty(sInput.Std)
        sInput.Std = [];
    end
    if isfield(sInput, 'TFmask') && ~isempty(sInput.TFmask)
        sInput.TFmask = [];
    end
end




