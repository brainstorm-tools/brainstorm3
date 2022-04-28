function varargout = process_average_time( varargin )
% PROCESS_AVERAGE_TIME: For each file in input, compute the mean (or the variance) over the time window.

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
% Authors: Francois Tadel, 2010-2021

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Average time';
    sProcess.FileTag     = @GetFileTag;
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Average';
    sProcess.Index       = 303;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Default values for some options
    sProcess.isSourceAbsolute = 1;
    
    % Definition of the options
    % === TIME WINDOW
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % === FUNCTION
    sProcess.options.label2.Comment = '<U><B>Function</B></U>:';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.avg_func.Comment = {'Arithmetic average:  <FONT color="#777777">mean(x)</FONT>', ...
                                         'Root mean square (RMS):  <FONT color="#777777">sqrt(sum(x.^2)/N)</FONT>', ...
                                         'Standard deviation:  <FONT color="#777777">sqrt(var(x))</FONT>', ...
                                         'Median:  <FONT color="#777777">median(x)</FONT>'; ...
                                         'mean', 'rms', 'std', 'median'};
    sProcess.options.avg_func.Type    = 'radio_label';
    sProcess.options.avg_func.Value   = 'mean';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Get time window
    Comment = [upper(GetFileTag(sProcess)), ': [', process_extract_time('GetTimeString', sProcess), ']'];
    % Absolute values 
    if isfield(sProcess.options, 'source_abs') && sProcess.options.source_abs.Value
        Comment = [Comment, ', abs'];
    end
end


%% ===== GET FILE TAG =====
function fileTag = GetFileTag(sProcess)
    % Old version of the process: option isstd={0,1}
    if isfield(sProcess.options, 'isstd') && ~isempty(sProcess.options.isstd) && sProcess.options.isstd.Value
        fileTag = 'std';
    % New version of the process: avg_fun={'mean','std','rms','median'}
    elseif isfield(sProcess.options, 'avg_func') && ~isempty(sProcess.options.avg_func) && ~isempty(sProcess.options.avg_func.Value)
        fileTag = sProcess.options.avg_func.Value;
    else
        fileTag = 'mean';
    end
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
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
    % Apply function
    switch GetFileTag(sProcess)
        case 'mean'
            sInput.A = mean(sInput.A(:,iTime,:), 2);
        case 'rms'
            sInput.A = sqrt(sum(sInput.A(:,iTime,:).^2, 2) / length(iTime));
        case 'std'
            sInput.A = sqrt(var(sInput.A(:,iTime,:), 0, 2));
        case 'median'
            sInput.A = median(sInput.A(:,iTime,:), 2);
    end
    % Copy values to represent the time window
    sInput.A = [sInput.A, sInput.A];
    % Keep only first and last time values
    if (length(iTime) >= 2)
        sInput.TimeVector = [sInput.TimeVector(iTime(1)), sInput.TimeVector(iTime(end))];
    % Only one time point: the duplicated time samples must have different time values
    else
        if (length(sInput.TimeVector) > 2)
            sInput.TimeVector = sInput.TimeVector(iTime(1)) + [0, sInput.TimeVector(2)-sInput.TimeVector(1)];
        else
            sInput.TimeVector = sInput.TimeVector(iTime(1)) + [0, 1e-6];
        end
    end
    % Build file tag
    sInput.CommentTag = [GetFileTag(sProcess) '(' process_extract_time('GetTimeString',sProcess,sInput) ')'];
    % Do not keep the Std/TFmask fields in the output
    if isfield(sInput, 'Std') && ~isempty(sInput.Std)
        sInput.Std = [];
    end
    if isfield(sInput, 'TFmask') && ~isempty(sInput.TFmask)
        sInput.TFmask = [];
    end
end




