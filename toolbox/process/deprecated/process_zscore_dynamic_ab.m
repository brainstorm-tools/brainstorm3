function varargout = process_zscore_dynamic_ab( varargin )
% PROCESS_ZSCORE_DYNAMIC_AB: Prepares a file for dynamic display of the zscore (load-time)
%
% DESCRIPTION:  For each channel:
%     1) Compute mean m and variance v for baseline
%     2) For each time sample, subtract m and divide by v
                        
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
% Authors: Francois Tadel, 2013-2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Z-score normalization (A=baseline) [DEPRECATED]';
    sProcess.Category    = 'File2';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 203;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/SourceEstimation#Z-score';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    sProcess.isPaired    = 1;
    
    % Definition of the options
    sProcess.options.description.Comment = ['For each signal in input:<BR>' ...
                                            '1) <B>FilesA</B>: Compute mean <I>m</I> and variance <I>v</I> for the baseline<BR>' ...
                                            '2) <B>FilesB</B>: For each time sample, subtract <I>m</I> and divide by <I>v</I><BR>' ...
                                            'Z = (Data - <I>m</I>) / <I>v</I><BR><BR>' ...
                                            '<B>Dynamic</B>: The standardized values are not saved to the file,<BR>' ...
                                            'they are computed on the fly when the file is loaded.<BR><BR>'];
    sProcess.options.description.Type    = 'label';
    % === Baseline time window
    sProcess.options.baseline.Comment = 'Baseline (Files A):';
    sProcess.options.baseline.Type    = 'baseline';
    sProcess.options.baseline.Value   = [];
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data'};
    % === Absolute values for sources
    sProcess.options.source_abs.Comment = ['<B>Use absolute values of source activations</B><BR>' ...
                                           'or the norm of the three orientations for unconstrained maps.'];
    sProcess.options.source_abs.Type    = 'checkbox';
    sProcess.options.source_abs.Value   = 0;
    sProcess.options.source_abs.InputTypes = {'results'};
    % === Dynamic Z-score
    sProcess.options.dynamic.Comment    = ['<B>Dynamic</B>: The standardized values are not saved to the file,<BR>' ...
                                           'they are computed on the fly when the file is loaded.<BR>' ...
                                           'Only available for constrained source models.'];
    sProcess.options.dynamic.Type       = 'checkbox';
    sProcess.options.dynamic.Value      = 1;
    sProcess.options.dynamic.InputTypes = {'results'};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
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
function OutputFiles = Run(sProcess, sInputBaseline, sInput) %#ok<DEFNU>
    % Call the base process
    OutputFiles = process_zscore_dynamic('Run', sProcess, sInputBaseline, sInput);
end


