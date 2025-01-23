function varargout = process_corr1n( varargin )
% PROCESS_CORR1N: Compute the correlation between all the pairs of signals, in one file.
%
% USAGE:  OutputFiles = process_corr1n('Run', sProcess, sInputA)

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
    sProcess.options.scalarprod.Comment    = 'Compute scalar product instead of correlation<BR>(do not remove average of the signal)';
    sProcess.options.scalarprod.Type       = 'checkbox';
    sProcess.options.scalarprod.Value      = 0;
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
function OutputFiles = Run(sProcess, sInputA) %#ok<DEFNU>
    % Input options
    OPTIONS = process_corr1n('GetConnectOptions', sProcess, sInputA);
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
    OutputFiles = bst_connectivity(sInputA, [], OPTIONS);
end


%% =================================================================================================
%  ====== COMMON TO ALL THE CONNECTIVITY PROCESSES =================================================
%  =================================================================================================

%% ===== DEFINE SCOUT OPTIONS =====
function sProcess = DefineConnectOptions(sProcess, isConnNN) %#ok<DEFNU>
    % === TIME WINDOW ===
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    sProcess.options.timewindow.Group   = 'input';
    % === FROM: CONNECTIVITY [1xN] ===
    if ~isConnNN
        % === FROM: REFERENCE CHANNELS ===
        sProcess.options.src_channel.Comment    = 'Source channel: ';
        sProcess.options.src_channel.Type       = 'channelname';
        sProcess.options.src_channel.Value      = 'name';
        sProcess.options.src_channel.InputTypes = {'data'};
        sProcess.options.src_channel.Group      = 'input';
        % === FROM: ROW NAME ===
        sProcess.options.src_rowname.Comment    = 'Signal names or indices: ';
        sProcess.options.src_rowname.Type       = 'text';
        sProcess.options.src_rowname.Value      = '';
        sProcess.options.src_rowname.InputTypes = {'timefreq', 'matrix'};
        sProcess.options.src_rowname.Group      = 'input';
    end
    % === TO: SENSOR SELECTION ===
    sProcess.options.dest_sensors.Comment    = 'Sensor types or names (empty=all): ';
    sProcess.options.dest_sensors.Type       = 'text';
    sProcess.options.dest_sensors.Value      = 'MEG, EEG';
    sProcess.options.dest_sensors.InputTypes = {'data'};
    sProcess.options.dest_sensors.Group      = 'input';
    % === TO: INCLUDE BAD CHANNELS ===
    sProcess.options.includebad.Comment    = 'Include bad channels';
    sProcess.options.includebad.Type       = 'checkbox';
    sProcess.options.includebad.Value      = 1;
    sProcess.options.includebad.InputTypes = {'data'};
    sProcess.options.includebad.Group      = 'input';
    % === SCOUTS ===
    sProcess.options.scouts.Comment = 'Use scouts';
    if isConnNN
        sProcess.options.scouts.Type = 'scout_confirm';
    else
        sProcess.options.scouts.Type = 'scout';
    end
    sProcess.options.scouts.Value      = {};
    sProcess.options.scouts.InputTypes = {'results'};
    sProcess.options.scouts.Group      = 'input';
    % === UNCONSTRAINED SOURCES ===
    sProcess.options.flatten.Comment    = 'Flatten unconstrained source orientations with PCA first';
    sProcess.options.flatten.Type       = 'checkbox';
    sProcess.options.flatten.Value      = 0;
    sProcess.options.flatten.InputTypes = {'results'};
    sProcess.options.flatten.Group      = 'input';
    % === SCOUT TIME ===
    sProcess.options.scouttime.Comment    = {'before&nbsp;&nbsp;&nbsp;', 'after&nbsp;&nbsp;&nbsp; connectivity metric', 'Scout function: &nbsp;&nbsp;&nbsp;Apply'; ...
                                             'before', 'after', ''};
    sProcess.options.scouttime.Type       = 'radio_linelabel';
    sProcess.options.scouttime.Value      = 'after';
    sProcess.options.scouttime.InputTypes = {'results'};
    sProcess.options.scouttime.Group      = 'input';
    sProcess.options.scouttime.Controller = struct('before', 'before', 'after', 'after');
    % === SCOUT FUNCTION ===    
    sProcess.options.scoutfunc.Comment    = {'PCA&nbsp;&thinsp;&thinsp;', 'Mean&nbsp;', 'All', '&nbsp;&nbsp;&nbsp;'; ...
                                             'pca', 'mean', 'all', ''};
    sProcess.options.scoutfunc.Type       = 'radio_linelabel';
    sProcess.options.scoutfunc.Value      = 'mean';
    sProcess.options.scoutfunc.InputTypes = {'results'};
    sProcess.options.scoutfunc.Group      = 'input';
    sProcess.options.scoutfunc.Class      = 'before';
    sProcess.options.scoutfuncaft.Comment    = {'Mean&nbsp;', 'Max&nbsp;&thinsp;&thinsp;', 'Std', '&nbsp;&nbsp;&nbsp;'; ...
                                             'mean', 'max', 'std', ''};
    sProcess.options.scoutfuncaft.Type       = 'radio_linelabel';
    sProcess.options.scoutfuncaft.Value      = 'mean';
    sProcess.options.scoutfuncaft.InputTypes = {'results'};
    sProcess.options.scoutfuncaft.Group      = 'input';
    sProcess.options.scoutfuncaft.Class      = 'after';    
    % Options: PCA, for orientations and/or scouts
    sProcess.options.pcaedit.Comment    = {'panel_pca', ' PCA options: '};
    sProcess.options.pcaedit.Type       = 'editpref';
    sProcess.options.pcaedit.Value      = bst_get('PcaOptions'); % function that returns defaults.
    sProcess.options.pcaedit.InputTypes = {'results'};
    sProcess.options.pcaedit.Group      = 'input';
end


%% ===== GET METRIC OPTIONS =====
% Note: Scout PCA options are not needed in bst_connectivity. bst_pca must be called by the process_ function, before bst_connectivity.
function OPTIONS = GetConnectOptions(sProcess, sInputA) %#ok<DEFNU>
    % Default options structure
    OPTIONS = bst_connectivity();
    % Get process name
    OPTIONS.ProcessName = func2str(sProcess.Function);

    % Connectivity type: [1xN] or [NxN]
    isConnNN = ismember(OPTIONS.ProcessName, {'process_corr1n', 'process_corr1n_time' ...
        'process_cohere1n', 'process_cohere1n_2021', 'process_cohere1n_time', 'process_cohere1n_time_2021', ...
        'process_granger1n', 'process_spgranger1n', ...
        'process_plv1n', 'process_pte1n', 'process_aec1n', 'process_henv1n'});
    
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
    % These scout options are set here even if scouts are NOT selected. To check if scouts are used,
    % check for nonempty TargetA/B (set below) of type cell or struct.
    if strcmpi(sInputA(1).FileType, 'results') && isfield(sProcess.options, 'scouts') && isfield(sProcess.options.scouts, 'Value')
        % Selected scouts
        AtlasList = sProcess.options.scouts.Value;
        % Override scout function (2023 change: two radio lists for before or after, checked below)
        switch (sProcess.options.scoutfunc.Value)
            case {1, 'mean'}, OPTIONS.ScoutFunc = 'mean'; 
            case {2, 'max'},  OPTIONS.ScoutFunc = 'max';  % OPTIONS.ScoutTime = 'after';
            case {3, 'pca'},  OPTIONS.ScoutFunc = 'pca';  % OPTIONS.ScoutTime = 'before';
            case {4, 'std'},  OPTIONS.ScoutFunc = 'std';  % OPTIONS.ScoutTime = 'after';
            case {5, 'all'},  OPTIONS.ScoutFunc = 'all';  % OPTIONS.ScoutTime = 'before';
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
        % Set input/output scouts functions
        if ~isempty(AtlasList)
            OPTIONS.TargetA = AtlasList;
            % Connectivity NxN: Use the same scouts for source and destination
            if isConnNN
                OPTIONS.TargetB = OPTIONS.TargetA;
            end
            % Connectivity 1xN: Can allow only one scout at a time. Check for multiple atlases and then multiple scouts.
            if ~isConnNN && (size(AtlasList,1) > 1 || ((size(AtlasList,2) >= 2) && (length(AtlasList{1,2}) > 1)))
                bst_report('Error', sProcess, [], 'Connectivity [1xN]: Please select only one scout at a time.');
                OPTIONS = [];
                return;
            end
        end
        % Scout PCA options
        if (strcmpi(OPTIONS.UnconstrFunc, 'pca') || strcmpi(OPTIONS.ScoutFunc, 'pca')) && isfield(sProcess.options, 'pcaedit') && isfield(sProcess.options.pcaedit, 'Value') && ~isempty(sProcess.options.pcaedit.Value)
            OPTIONS.PcaOptions = sProcess.options.pcaedit.Value;
        end
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


