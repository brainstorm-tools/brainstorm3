function varargout = process_corr2( varargin )
% PROCESS_CORR2: Compute the correlation between one signal in one file, and all the signals in another file.
%
% USAGE:  OutputFiles = process_corr2('Run', sProcess, sInputA, sInputB)

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
% Authors: Francois Tadel, 2012-2020
%          Raymundo Cassani, 2023

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
    % === TIME RESOLUTION
    sProcess.options.timeres.Comment = {'Windowed', 'None', '<B>Time resolution:</B>'; ...
                                        'windowed', 'none', ''};
    sProcess.options.timeres.Type    = 'radio_linelabel';
    sProcess.options.timeres.Value   = 'none';
    sProcess.options.timeres.Controller = struct('windowed', 'windowed', 'none', 'nowindowed');
    % === WINDOW LENGTH
    sProcess.options.avgwinlength.Comment = '&nbsp;&nbsp;&nbsp;Time window length:';
    sProcess.options.avgwinlength.Type    = 'value';
    sProcess.options.avgwinlength.Value   = {1, 's', []};
    sProcess.options.avgwinlength.Class   = 'windowed';
    % === WINDOW OVERLAP
    sProcess.options.avgwinoverlap.Comment = '&nbsp;&nbsp;&nbsp;Time window overlap:';
    sProcess.options.avgwinoverlap.Type    = 'value';
    sProcess.options.avgwinoverlap.Value   = {50, '%', []};
    sProcess.options.avgwinoverlap.Class   = 'windowed';
    % === SCALAR PRODUCT
    sProcess.options.scalarprod.Comment = 'Compute scalar product instead of correlation<BR>(do not remove average of the signal)';
    sProcess.options.scalarprod.Type    = 'checkbox';
    sProcess.options.scalarprod.Value   = 0;
    % === OUTPUT MODE
    sProcess.options.outputmode.Comment = {'separately for each file', 'average over files/epochs', 'Estimate & save:'; ...
                                            'input', 'avg', ''};
    sProcess.options.outputmode.Type    = 'radio_linelabel';
    sProcess.options.outputmode.Value   = 'input';
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
    if strcmpi(sProcess.options.timeres.Value, 'windowed')
        OPTIONS.WinLen = sProcess.options.avgwinlength.Value{1};
        OPTIONS.WinOverlap = sProcess.options.avgwinoverlap.Value{1}/100;
    end
    % Time-resolved; now option, no longer separate process
    OPTIONS.TimeRes = sProcess.options.timeres.Value;
    
    % Compute metric
    OutputFiles = bst_connectivity(sInputA, sInputB, OPTIONS);
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
    sProcess.options.src_rowname.Comment     = 'Signal names or indices (A): ';
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
    % === UNCONSTRAINED SOURCES ===
    sProcess.options.flatten.Comment     = 'Flatten unconstrained source orientations with PCA first';
    sProcess.options.flatten.Type        = 'checkbox';
    sProcess.options.flatten.Value       = 0;
    sProcess.options.flatten.InputTypes  = {'results'};
    sProcess.options.flatten.InputTypesB = {'results'};
    sProcess.options.flatten.Group       = 'input';
    % === SCOUT TIME ===
    sProcess.options.scouttime.Comment       = {'before&nbsp;&nbsp;&nbsp;', 'after&nbsp;&nbsp;&nbsp; connectivity metric', 'Scout function: &nbsp;&nbsp;&nbsp;Apply'; ...
                                                'before', 'after', ''};
    sProcess.options.scouttime.Type          = 'radio_linelabel';
    sProcess.options.scouttime.Value         = 'after';
    sProcess.options.scouttime.InputTypes    = {'results'};
    sProcess.options.scouttime.InputTypesB   = {'results'};
    sProcess.options.scouttime.Group         = 'input';
    sProcess.options.scouttime.Controller    = struct('before', 'before', 'after', 'after');
    % === SCOUT FUNCTION ===    
    sProcess.options.scoutfunc.Comment        = {'PCA&nbsp;&thinsp;&thinsp;', 'Mean&nbsp;', 'All', '&nbsp;&nbsp;&nbsp;'; ...
                                                'pca', 'mean', 'all', ''};
    sProcess.options.scoutfunc.Type           = 'radio_linelabel';
    sProcess.options.scoutfunc.Value          = 'mean';
    sProcess.options.scoutfunc.InputTypes     = {'results'};
    sProcess.options.scoutfunc.InputTypesB    = {'results'};
    sProcess.options.scoutfunc.Group          = 'input';
    sProcess.options.scoutfunc.Class          = 'before';
    sProcess.options.scoutfuncaft.Comment     = {'Mean&nbsp;', 'Max&nbsp;&thinsp;&thinsp;', 'Std', '&nbsp;&nbsp;&nbsp;'; ...
                                                'mean', 'max', 'std', ''};
    sProcess.options.scoutfuncaft.Type        = 'radio_linelabel';
    sProcess.options.scoutfuncaft.Value       = 'mean';
    sProcess.options.scoutfuncaft.InputTypes  = {'results'};
    sProcess.options.scoutfuncaft.InputTypesB = {'results'};
    sProcess.options.scoutfuncaft.Group       = 'input';
    sProcess.options.scoutfuncaft.Class       = 'after';
    % Options: PCA, for orientations and/or scouts
    sProcess.options.pcaedit.Comment     = {'panel_pca', ' PCA options: '};
    sProcess.options.pcaedit.Type        = 'editpref';
    sProcess.options.pcaedit.Value       = bst_get('PcaOptions'); % function that returns defaults.
    sProcess.options.pcaedit.InputTypes  = {'results'};
    sProcess.options.pcaedit.InputTypesB = {'results'};
    sProcess.options.pcaedit.Group       = 'input';
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
    sProcess.options.dest_rowname.Comment     = 'Signal names or indices (B): ';
    sProcess.options.dest_rowname.Type        = 'text';
    sProcess.options.dest_rowname.Value       = '';
    sProcess.options.dest_rowname.InputTypesB = {'timefreq', 'matrix'};
    sProcess.options.dest_rowname.Group       = 'input';
end


%% ===== GET METRIC OPTIONS =====
function OPTIONS = GetConnectOptions(sProcess, sInputA, sInputB) %#ok<DEFNU>
    % Default options structure
    OPTIONS = bst_connectivity();
    % Get process name
    OPTIONS.ProcessName = func2str(sProcess.Function);

    % === TIME WINDOW ===
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value)
        OPTIONS.TimeWindow = sProcess.options.timewindow.Value{1};
    end
    % === UNCONSTRAINED SOURCE ORIENTATIONS ===
    if isfield(sProcess.options, 'flatten') && isfield(sProcess.options.flatten, 'Value') && ~isempty(sProcess.options.flatten.Value)
        if sProcess.options.flatten.Value
            OPTIONS.UnconstrFunc = 'pca';
        else
            OPTIONS.UnconstrFunc = 'max'; % not used explicitly, but saved in output (if max actually applied)
        end
    end
    % === SCOUTS ===
    % These scout options are set here even if scouts are NOT selected. To check if scouts are used,
    % check for nonempty TargetA/B (set below) of type cell or struct.
    if isfield(sProcess.options, 'scoutfunc') && isfield(sProcess.options.scoutfunc, 'Value') && isfield(sProcess.options, 'scouttime') && isfield(sProcess.options.scouttime, 'Value')
        % Override scouts function
        switch (sProcess.options.scoutfunc.Value)
            case {1, 'mean'}, OPTIONS.ScoutFunc = 'mean';
            case {2, 'max'},  OPTIONS.ScoutFunc = 'max';
            case {3, 'pca'},  OPTIONS.ScoutFunc = 'pca';
            case {4, 'std'},  OPTIONS.ScoutFunc = 'std';
            case {5, 'all'},  OPTIONS.ScoutFunc = 'all';
            otherwise 
                bst_report('Error', sProcess, [], 'Invalid scout function.'); 
                OPTIONS = [];
                return;
        end
        % Scout function order 
        if isfield(sProcess.options, 'scouttime')
            switch (sProcess.options.scouttime.Value)
                case {1, 'before'}
                    OPTIONS.ScoutTime = 'before';
                    if ismember(OPTIONS.ScoutFunc, {'max', 'std'}) % No longer possible in GUI
                        bst_report('Error', sProcess, [], 'Scout functions MAX and STD cannot be applied before estimating the connectivity.');
                        OPTIONS = [];
                        return;
                    end
                case {2, 'after'}
                    OPTIONS.ScoutTime = 'after';
                    % 2023 GUI change: get scout function from separate "after" list
                    if isfield(sProcess.options, 'scoutfuncaft')
                        OPTIONS.ScoutFunc = sProcess.options.scoutfuncaft.Value;
                    end
                    if strcmpi(OPTIONS.ScoutFunc, 'pca') % No longer possible in GUI
                        bst_report('Error', sProcess, [], 'Scout function PCA cannot be applied after estimating the connectivity.');
                        OPTIONS = [];
                        return;
                    end
            end
        end
        % Scout PCA options: copy only so they are saved in output files, for documentation; OPTIONS not actually used for PCA computation.
        if (strcmpi(OPTIONS.UnconstrFunc, 'pca') || strcmpi(OPTIONS.ScoutFunc, 'pca')) && isfield(sProcess.options, 'pcaedit') && isfield(sProcess.options.pcaedit, 'Value') && ~isempty(sProcess.options.pcaedit.Value)
            OPTIONS.PcaOptions = sProcess.options.pcaedit.Value;
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
    % Output mode: 'radio_label' option (2021)
    if ischar(sProcess.options.outputmode.Value)
        OPTIONS.OutputMode = sProcess.options.outputmode.Value;
    % Output mode: 'radio' option (deprecated)
    else
        strOutput = lower(sProcess.options.outputmode.Comment{sProcess.options.outputmode.Value});
        if ~isempty(strfind(strOutput, 'average'))
            OPTIONS.OutputMode = 'avg';
        elseif ~isempty(strfind(strOutput, 'concatenate'))
            OPTIONS.OutputMode = 'concat';
        else
            OPTIONS.OutputMode = 'input';
        end
    end
    % Output study, in case of average
    if ismember(OPTIONS.OutputMode, {'avg', 'concat', 'avgcoh'})
        if ~isempty(sInputB)
            [tmp, OPTIONS.iOutputStudy] = bst_process('GetOutputStudy', sProcess, sInputB);
        else
            [tmp, OPTIONS.iOutputStudy] = bst_process('GetOutputStudy', sProcess, sInputA);
        end
    end
end


