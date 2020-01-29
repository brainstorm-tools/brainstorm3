function varargout = process_corr1n( varargin )
% PROCESS_CORR1N: Compute the correlation between all the pairs of signals, in one file.
%
% USAGE:  OutputFiles = process_corr1n('Run', sProcess, sInputA)

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
% Authors: Francois Tadel, 2012-2014

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Correlation NxN';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Connectivity';
    sProcess.Index       = 652;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data',     'results',  'matrix'};
    sProcess.OutputTypes = {'timefreq', 'timefreq', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    
    % === CONNECT INPUT
    sProcess = process_corr1n('DefineConnectOptions', sProcess, 1);
    % === TITLE
    sProcess.options.label2.Comment = '<BR><U><B>Estimator options</B></U>:';
    sProcess.options.label2.Type    = 'label';
%     % === P-VALUE THRESHOLD
%     sProcess.options.pthresh.Comment = 'Metric significativity: &nbsp;&nbsp;&nbsp;&nbsp;p&lt;';
%     sProcess.options.pthresh.Type    = 'value';
%     sProcess.options.pthresh.Value   = {0.05,'',4};
    % === SCALAR PRODUCT
    sProcess.options.scalarprod.Comment    = 'Compute scalar product instead of correlation<BR>(do not remove average of the signal)';
    sProcess.options.scalarprod.Type       = 'checkbox';
    sProcess.options.scalarprod.Value      = 0;
    % === OUTPUT MODE
    sProcess.options.label3.Comment = '<BR><U><B>Output configuration</B></U>:';
    sProcess.options.label3.Type    = 'label';
    sProcess.options.outputmode.Comment = {'Save individual results (one file per input file)', 'Save average connectivity matrix (one file)'};
    sProcess.options.outputmode.Type    = 'radio';
    sProcess.options.outputmode.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputA) %#ok<DEFNU>
    % Input options
    OPTIONS = process_corr1n('GetConnectOptions', sProcess, sInputA);
    if isempty(OPTIONS)
        OutputFiles = {};
        return
    end
    
    % Metric options
    OPTIONS.Method     = 'corr';
    OPTIONS.pThresh    = 0.05;  % sProcess.options.pthresh.Value{1};
    OPTIONS.RemoveMean = ~sProcess.options.scalarprod.Value;

    % Compute metric
    OutputFiles = bst_connectivity({sInputA.FileName}, [], OPTIONS);
end


%% =================================================================================================
%  ====== COMMON TO ALL THE CONNECTIVITY PROCESSES =================================================
%  =================================================================================================

%% ===== DEFINE SCOUT OPTIONS =====
function sProcess = DefineConnectOptions(sProcess, isConnNN) %#ok<DEFNU>
    % === TIME WINDOW ===
    sProcess.options.label1.Comment = '<B><U>Input options</U></B>:';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % === FROM: CONNECTIVITY [1xN] ===
    if ~isConnNN
        % === FROM: REFERENCE CHANNELS ===
        sProcess.options.src_channel.Comment    = 'Source channel: ';
        sProcess.options.src_channel.Type       = 'channelname';
        sProcess.options.src_channel.Value      = 'name';
        sProcess.options.src_channel.InputTypes = {'data'};
        % === FROM: ROW NAME ===
        sProcess.options.src_rowname.Comment    = 'Source rows (names or indices): ';
        sProcess.options.src_rowname.Type       = 'text';
        sProcess.options.src_rowname.Value      = '';
        sProcess.options.src_rowname.InputTypes = {'timefreq', 'matrix'};
    end
    % === TO: SENSOR SELECTION ===
    sProcess.options.dest_sensors.Comment    = 'Sensor types or names (empty=all): ';
    sProcess.options.dest_sensors.Type       = 'text';
    sProcess.options.dest_sensors.Value      = 'MEG, EEG';
    sProcess.options.dest_sensors.InputTypes = {'data'};
    % === TO: INCLUDE BAD CHANNELS ===
    sProcess.options.includebad.Comment    = 'Include bad channels';
    sProcess.options.includebad.Type       = 'checkbox';
    sProcess.options.includebad.Value      = 1;
    sProcess.options.includebad.InputTypes = {'data'};
    % === SCOUTS ===
    sProcess.options.scouts.Comment = 'Use scouts';
    if isConnNN
        sProcess.options.scouts.Type = 'scout_confirm';
    else
        sProcess.options.scouts.Type = 'scout';
    end
    sProcess.options.scouts.Value      = {};
    sProcess.options.scouts.InputTypes = {'results'};
    % === SCOUT FUNCTION ===
    sProcess.options.scoutfunc.Comment    = {'Mean', 'Max', 'PCA', 'Std', 'All', 'Scout function:'};
    sProcess.options.scoutfunc.Type       = 'radio_line';
    sProcess.options.scoutfunc.Value      = 1;
    sProcess.options.scoutfunc.InputTypes = {'results'};
    % === SCOUT TIME ===
    sProcess.options.scouttime.Comment    = {'Before', 'After', 'When to apply the scout function:'};
    sProcess.options.scouttime.Type       = 'radio_line';
    sProcess.options.scouttime.Value      = 2;
    sProcess.options.scouttime.InputTypes = {'results'};
end


%% ===== GET METRIC OPTIONS =====
function OPTIONS = GetConnectOptions(sProcess, sInputA) %#ok<DEFNU>
    % Default options structure
    OPTIONS = bst_connectivity();
    % Get process name
    OPTIONS.ProcessName = func2str(sProcess.Function);
    % Connectivity type: [1xN] or [NxN]
    isConnNN = ismember(OPTIONS.ProcessName, {'process_corr1n', 'process_cohere1n', 'process_granger1n',...
        'process_spgranger1n', 'process_plv1n', 'process_corr1n_time', 'process_cohere1n_time',...
        'process_pte1n', 'process_aec1n'});
    
    % === TIME WINDOW ===
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value)
        OPTIONS.TimeWindow = sProcess.options.timewindow.Value{1};
    end
    % === FROM: REFERENCE CHANNELS ===
    if strcmpi(sInputA(1).FileType, 'data') && isfield(sProcess.options, 'src_channel') && isfield(sProcess.options.src_channel, 'Value')
        OPTIONS.TargetA = sProcess.options.src_channel.Value;
    end
    % === FROM: ROW NAME ===
    if any(strcmpi(sInputA(1).FileType, {'timefreq','matrix'})) && isfield(sProcess.options, 'src_rowname') && isfield(sProcess.options.src_rowname, 'Value')
        OPTIONS.TargetA = sProcess.options.src_rowname.Value;
    end
    % === TO: SENSOR SELECTION ===
    if strcmpi(sInputA(1).FileType, 'data') && isfield(sProcess.options, 'dest_sensors') && isfield(sProcess.options.dest_sensors, 'Value')
        if isConnNN
            OPTIONS.TargetA = sProcess.options.dest_sensors.Value;
        else
            OPTIONS.TargetB = sProcess.options.dest_sensors.Value;
        end
    end
    % === TO: INCLUDE BAD CHANNELS ===
    if strcmpi(sInputA(1).FileType, 'data') && isfield(sProcess.options, 'includebad') && isfield(sProcess.options.includebad, 'Value')
        OPTIONS.IgnoreBad = ~sProcess.options.includebad.Value;
    end
    % === SCOUTS ===
    if strcmpi(sInputA(1).FileType, 'results') && isfield(sProcess.options, 'scouts') && isfield(sProcess.options.scouts, 'Value')
        % Selected scouts
        AtlasList = sProcess.options.scouts.Value;
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
        % Set input/output scouts functions
        if ~isempty(AtlasList)
            OPTIONS.TargetA = AtlasList;
            % Connectivity NxN: Use the same scouts for source and destination
            if isConnNN
                OPTIONS.TargetB = OPTIONS.TargetA;
            end
            % Connectivity 1xN: Can allow only one scout at a time
            if ~isConnNN && (size(AtlasList,2) > 2) && (length(AtlasList{1,2}) > 1)
                bst_report('Error', sProcess, [], 'Connectivity [1xN]: Please select only one scout at a time.');
                OPTIONS = [];
                return;
            end
        end
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
    if ismember(OPTIONS.OutputMode, {'avg', 'concat'})
        [tmp, OPTIONS.iOutputStudy] = bst_process('GetOutputStudy', sProcess, sInputA);
    end
end




%% ===== TEST FUNCTION =====
function Test() %#ok<DEFNU>
    % Start a new report
    bst_report('Start');
    % Get test datasets
    sFile = process_simulate_ar('Test');
    % Coherence process
    sTmp = bst_process('CallProcess', 'process_corr1n', sFile, [], ...
        'timewindow',   [], ...    % All the time in input
        'pthresh',      0.05, ...
        'scalarprod',   0, ...
        'outputmode',   1);        % Save individual results (one file per input file)
    % Snapshot: spectrum
    bst_process('CallProcess', 'process_snapshot', sTmp, [], ...
        'target',       11, ...  % Connectivity matrix (image)
        'modality',     1, 'orient', 1, 'time', 0, 'contact_time', [-40, 110], 'contact_nimage', 16, ...
        'Comment',      [sFile.Comment, ': ' sTmp.Comment]);
    % Save and display report
    ReportFile = bst_report('Save', sFile);
    bst_report('Open', ReportFile);
end


