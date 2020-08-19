function varargout = process_corr2( varargin )
% PROCESS_CORR2: Compute the correlation between one signal in one file, and all the signals in another file.
%
% USAGE:  OutputFiles = process_corr2('Run', sProcess, sInputA, sInputB)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2012-2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Correlation AxB';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Connectivity';
    sProcess.Index       = 651;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'matrix'};
    sProcess.OutputTypes = {'timefreq', 'timefreq', 'timefreq'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    sProcess.isPaired    = 1;
    
    % === CONNECT INPUT
    sProcess = process_corr2('DefineConnectOptions', sProcess);
    % === SCALAR PRODUCT
    sProcess.options.scalarprod.Comment = 'Compute scalar product instead of correlation<BR>(do not remove average of the signal)';
    sProcess.options.scalarprod.Type    = 'checkbox';
    sProcess.options.scalarprod.Value   = 0;
    % === OUTPUT MODE
    sProcess.options.outputmode.Comment = {'Save individual results (one file per input file)', 'Save average connectivity matrix (one file)'};
    sProcess.options.outputmode.Type    = 'radio';
    sProcess.options.outputmode.Value   = 1;
    sProcess.options.outputmode.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputA, sInputB) %#ok<DEFNU>
    % Input options
    OPTIONS = process_corr2('GetConnectOptions', sProcess, sInputA, sInputB);
    if isempty(OPTIONS)
        OutputFiles = {};
        return
    end
    
    % Metric options
    OPTIONS.Method     = 'corr';
    OPTIONS.pThresh    = 0.05;
    OPTIONS.RemoveMean = ~sProcess.options.scalarprod.Value;
    
    % Compute metric
    OutputFiles = bst_connectivity({sInputA.FileName}, {sInputB.FileName}, OPTIONS);
end



%% =================================================================================================
%  ====== COMMON TO ALL THE CONNECTIVITY PROCESSES =================================================
%  =================================================================================================

%% ===== DEFINE SCOUT OPTIONS =====
function sProcess = DefineConnectOptions(sProcess) %#ok<DEFNU>
    % === TIME WINDOW ===
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    sProcess.options.timewindow.Group   = 'input';
    % === FROM: REFERENCE CHANNELS ===
    sProcess.options.src_channel.Comment    = 'Source channel (A): ';
    sProcess.options.src_channel.Type       = 'channelname';
    sProcess.options.src_channel.Value      = 'name';
    sProcess.options.src_channel.InputTypes = {'data'};
    sProcess.options.src_channel.Group      = 'input';
    % === FROM: ROW NAME ===
    sProcess.options.src_rowname.Comment     = 'Row name or index (A): ';
    sProcess.options.src_rowname.Type        = 'text';
    sProcess.options.src_rowname.Value       = '';
    sProcess.options.src_rowname.InputTypes  = {'timefreq', 'matrix'};
    sProcess.options.src_rowname.Group       = 'input';
    % === FROM: SCOUTS ===
    sProcess.options.src_scouts.Comment    = 'Use scouts (A)';
    sProcess.options.src_scouts.Type       = 'scout_confirm';
    sProcess.options.src_scouts.Value      = {};
    sProcess.options.src_scouts.InputTypes = {'results'};
    sProcess.options.src_scouts.Group      = 'input';
    % === TO: SCOUTS ===
    sProcess.options.dest_scouts.Comment     = 'Use scouts (B)';
    sProcess.options.dest_scouts.Type        = 'scout_confirm';
    sProcess.options.dest_scouts.Value       = {};
    sProcess.options.dest_scouts.InputTypesB = {'results'};
    sProcess.options.dest_scouts.Group       = 'input';
    % === SCOUT FUNCTION ===
    sProcess.options.scoutfunc.Comment     = {'Mean', 'Max', 'PCA', 'Std', 'All', 'Scout function:'};
    sProcess.options.scoutfunc.Type        = 'radio_line';
    sProcess.options.scoutfunc.Value       = 1;
    sProcess.options.scoutfunc.InputTypes  = {'results'};
    sProcess.options.scoutfunc.InputTypesB = {'results'};
    sProcess.options.scoutfunc.Group       = 'input';
    % === SCOUT TIME ===
    sProcess.options.scouttime.Comment     = {'Before', 'After', 'When to apply the scout function:'};
    sProcess.options.scouttime.Type        = 'radio_line';
    sProcess.options.scouttime.Value       = 2;
    sProcess.options.scouttime.InputTypes  = {'results'};
    sProcess.options.scouttime.InputTypesB = {'results'};
    sProcess.options.scouttime.Group       = 'input';
    % === TO: SENSOR SELECTION ===
    sProcess.options.dest_sensors.Comment     = 'Sensor types or names (B): ';
    sProcess.options.dest_sensors.Type        = 'text';
    sProcess.options.dest_sensors.Value       = 'MEG, EEG';
    sProcess.options.dest_sensors.InputTypesB = {'data'};
    sProcess.options.dest_sensors.Group       = 'input';
    % === TO: INCLUDE BAD CHANNELS ===
    sProcess.options.includebad.Comment     = 'Include bad channels';
    sProcess.options.includebad.Type        = 'checkbox';
    sProcess.options.includebad.Value       = 1;
    sProcess.options.includebad.InputTypesB = {'data'};
    sProcess.options.includebad.Group       = 'input';
    % === TO: ROW NAME ===
    sProcess.options.dest_rowname.Comment     = 'Row names or indices (B): ';
    sProcess.options.dest_rowname.Type        = 'text';
    sProcess.options.dest_rowname.Value       = '';
    sProcess.options.dest_rowname.InputTypesB = {'timefreq', 'matrix'};
    sProcess.options.dest_rowname.Group       = 'input';
end


%% ===== GET SCOUTS OPTIONS =====
function OPTIONS = GetConnectOptions(sProcess, sInputA, sInputB) %#ok<DEFNU>
    % Default options structure
    OPTIONS = bst_connectivity();
    % Get process name
    OPTIONS.ProcessName = func2str(sProcess.Function);
    
    % === TIME WINDOW ===
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value)
        OPTIONS.TimeWindow = sProcess.options.timewindow.Value{1};
    end
    
    % === SCOUT FUNCTION ===
    if isfield(sProcess.options, 'scoutfunc') && isfield(sProcess.options.scoutfunc, 'Value') && isfield(sProcess.options, 'scouttime') && isfield(sProcess.options.scouttime, 'Value')
        % Override scouts function
        switch (sProcess.options.scoutfunc.Value)
            case 1, OPTIONS.ScoutFunc = 'mean';
            case 2, OPTIONS.ScoutFunc = 'max';
            case 3, OPTIONS.ScoutFunc = 'pca';
            case 4, OPTIONS.ScoutFunc = 'std';
            case 5, OPTIONS.ScoutFunc = 'all';
        end
        % Scout function order
        switch (sProcess.options.scouttime.Value)
            case 1, OPTIONS.ScoutTime = 'before';
            case 2, OPTIONS.ScoutTime = 'after';
        end
        % Perform some checks
        if strcmpi(OPTIONS.ScoutTime, 'before') && ismember(OPTIONS.ScoutFunc, {'max', 'std'})
            bst_report('Error', sProcess, [], 'Scout functions MAX and STD should not be applied before estimating the connectivity.');
            OPTIONS = [];
            return;
        end
        if strcmpi(OPTIONS.ScoutTime, 'after') && strcmpi(OPTIONS.ScoutFunc, 'pca')
            bst_report('Error', sProcess, [], 'Scout function PCA cannot be applied after estimating the connectivity.');
            OPTIONS = [];
            return;
        end
    end
    
    % === FROM: REFERENCE CHANNELS ===
    if strcmpi(sInputA(1).FileType, 'data') && isfield(sProcess.options, 'src_channel') && isfield(sProcess.options.src_channel, 'Value')
        OPTIONS.TargetA = sProcess.options.src_channel.Value;
    end
    % === FROM: ROW NAME ===
    if ismember(sInputA(1).FileType, {'timefreq','matrix'}) && isfield(sProcess.options, 'src_rowname') && isfield(sProcess.options.src_rowname, 'Value')
        OPTIONS.TargetA = sProcess.options.src_rowname.Value;
    end
    % === FROM: SCOUTS ===
    if strcmpi(sInputA(1).FileType, 'results') && isfield(sProcess.options, 'src_scouts') && isfield(sProcess.options.src_scouts, 'Value') && ~isempty(sProcess.options.src_scouts.Value)
        OPTIONS.TargetA = sProcess.options.src_scouts.Value;
    end
    
    % === TO: SENSOR SELECTION ===
    if strcmpi(sInputB(1).FileType, 'data') && isfield(sProcess.options, 'dest_sensors') && isfield(sProcess.options.dest_sensors, 'Value')
        OPTIONS.TargetB = sProcess.options.dest_sensors.Value;
    end
    % === TO: INCLUDE BAD CHANNELS ===
    if strcmpi(sInputB(1).FileType, 'data') && isfield(sProcess.options, 'includebad') && isfield(sProcess.options.includebad, 'Value')
        OPTIONS.IgnoreBad = ~sProcess.options.includebad.Value;
    end
    % === TO: ROW NAME ===
    if ismember(sInputB(1).FileType, {'timefreq','matrix'}) && isfield(sProcess.options, 'dest_rowname') && isfield(sProcess.options.dest_rowname, 'Value')
        OPTIONS.TargetB = sProcess.options.dest_rowname.Value;
    end
    % === TO: SCOUTS ===
    if strcmpi(sInputB(1).FileType, 'results') && isfield(sProcess.options, 'dest_scouts') && isfield(sProcess.options.dest_scouts, 'Value') && ~isempty(sProcess.options.dest_scouts.Value)
        OPTIONS.TargetB = sProcess.options.dest_scouts.Value;
    end
    % === FILE TYPE: NO TIMEFREQ ===
    if strcmpi(sInputA(1).FileType, 'timefreq') || strcmpi(sInputB(1).FileType, 'timefreq')
        bst_report('Error', sProcess, [], 'Time-frequency files are not allowed in input of this process.');
        OPTIONS = [];
        return;
    end

    % === OUTPUT ===
    % Output mode
    strOutput = lower(sProcess.options.outputmode.Comment{sProcess.options.outputmode.Value});
    if ~isempty(strfind(strOutput, 'average'))
        OPTIONS.OutputMode = 'avg';
    elseif ~isempty(strfind(strOutput, 'concatenate'))
        OPTIONS.OutputMode = 'concat';
    else
        OPTIONS.OutputMode = 'input';
    end
    % Output study, in case of average
    if strcmpi(OPTIONS.OutputMode, 'avg') || strcmpi(OPTIONS.OutputMode, 'concat')
        if ~isempty(sInputB)
            [tmp, OPTIONS.iOutputStudy] = bst_process('GetOutputStudy', sProcess, sInputB);
        else
            [tmp, OPTIONS.iOutputStudy] = bst_process('GetOutputStudy', sProcess, sInputA);
        end
    end
end


