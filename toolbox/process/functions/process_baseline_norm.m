function varargout = process_baseline_norm( varargin )
% PROCESS_BASELINE_NORM: Normalization with respect to a baseline.
%
% USAGE:      sProcess = process_baseline_norm('GetDescription')
%               sInput = process_baseline_norm('Run',     sProcess, sInput)
%              sInputB = process_baseline_norm('Run',     sProcess, sInputA, sInputB)
%                Fdata = process_baseline_norm('Compute', Fdata, Fbaseline, Method) 
%
% METHODS:
%    - 'zscore'   : (x-mean)/std
%    - 'ersd'     : (x-mean)/mean*100
%    - 'bl'       : (x-mean)
%    - 'divmean'  : (x/mean)
%    - 'db'       : 10*log10(x/mean)
%    - 'contrast' : (x-mean)/(x+mean)
                        
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
% Authors: Francois Tadel, 2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Baseline normalization';
    sProcess.FileTag     = @GetFileTag;
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 415;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/SourceEstimation#Z-score';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Default values for some options
    sProcess.isSourceAbsolute = 0;
    sProcess.processDim       = 1;    % Process channel by channel
    
    % === Process description
    sProcess.options.label1.Comment = ['This process normalizes each signal and frequency bin separately<BR>' ...
                                       'with respect to baseline. In the formulas below:<BR>'...
                                       '&nbsp; <B>x</B> = data to normalize<BR>' ...
                                       '&nbsp; <B>&mu;</B> = mean over the baseline&nbsp;&nbsp;&nbsp;<FONT color=#7F7F7F>[mean(x(iBaseline))]</FONT><BR>' ...
                                       '&nbsp; <B>&sigma;</B> = standard deviation over the baseline&nbsp;&nbsp;&nbsp;<FONT color=#7F7F7F>[std(x(iBaseline))]</FONT><BR><BR>'];
    sProcess.options.label1.Type = 'label';
    % Common options
    sProcess = DefineOptions(sProcess);
end


%% ===== DEFINE OPTIONS =====
function sProcess = DefineOptions(sProcess)
    % === Baseline time window
    sProcess.options.baseline.Comment = 'Baseline:';
    sProcess.options.baseline.Type    = 'baseline';
    sProcess.options.baseline.Value   = [];
    sProcess.options.baseline.Group   = 'input';
    % === Sensor types
    sProcess.options.sensortypes.Comment    = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type       = 'text';
    sProcess.options.sensortypes.Value      = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data'};
    sProcess.options.sensortypes.Group      = 'input';
    % === Source absolute value
    sProcess.options.source_abs.Comment    = ['Normalize absolute values (or norm for unconstrained sources)<BR>' ...
                                              '<FONT color=#7F7F7F>Not recommended (see online tutorials for help)</FONT>'];
    sProcess.options.source_abs.Type       = 'checkbox';
    sProcess.options.source_abs.Value      = 0;
    sProcess.options.source_abs.InputTypes = {'results'};
    sProcess.options.source_abs.Group      = 'input';
    % === Method
    sProcess.options.method.Comment = {['Z-score transformation: <FONT color=#7F7F7F>&nbsp;&nbsp;&nbsp;' ...
                                            'x_std = (x - &mu;) / &sigma;'], ...
                                       ['Event-related perturbation (ERS/ERD): <FONT color=#7F7F7F>&nbsp;&nbsp;&nbsp;' ...
                                            'x_std = (x - &mu;) / &mu; * 100'], ...
                                       ['DC offset correction: <FONT color=#7F7F7F>&nbsp;&nbsp;&nbsp;' ...
                                            'x_std = x - &mu;'], ...
                                       ['Scale with the mean: <FONT color=#7F7F7F>&nbsp;&nbsp;&nbsp;' ...
                                            'x_std = x / &mu;'], ...
                                       ['Scale with the mean (dB): <FONT color=#7F7F7F>&nbsp;&nbsp;&nbsp;' ...
                                            'x_std = 10 * log10(x / &mu;)'], ...
                                       ['Contrast with the mean: <FONT color=#7F7F7F>&nbsp;&nbsp;&nbsp;' ...
                                            'x_std = (x - &mu;) / (x + &mu;)']; ...
                                       'zscore', 'ersd', 'bl', 'divmean', 'db', 'contrast'};
    sProcess.options.method.Type    = 'radio_label';
    sProcess.options.method.Value   = 'zscore';
    % === Warning
    sProcess.options.label3.Comment = '&nbsp;<FONT color=#7F7F7F>Warning: The "Z-score" values follow a Z distribution <B>iif x~N(&mu;,&sigma;)</B></FONT>';
    sProcess.options.label3.Type = 'label';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Get method
    iMethod = find(strcmpi(sProcess.options.method.Value, sProcess.options.method.Comment(2,:)));
    if ~isempty(iMethod)
        strMethod = sProcess.options.method.Comment{1,iMethod};
        iEnd = find(strMethod == ':', 1);
        if ~isempty(iEnd)
            strMethod = strMethod(1:iEnd-1);
        end
    else
        strMethod = 'Invalid method';
    end
    % Get time window
    if isfield(sProcess.options, 'baseline') && isfield(sProcess.options.baseline, 'Value') && iscell(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value{1})
        Time = sProcess.options.baseline.Value{1};
    else
        Time = [];
    end
    % Add time window to the comment
    if isempty(Time)
        Comment = [strMethod, ': [All file]'];
    elseif any(abs(Time) > 2)
        Comment = [strMethod, sprintf(': [%1.3fs,%1.3fs]', Time(1), Time(2))];
    else
        Comment = [strMethod, sprintf(': [%dms,%dms]', round(Time(1)*1000), round(Time(2)*1000))];
    end
end


%% ===== GET FILE TAG =====
function fileTag = GetFileTag(sProcess)
    fileTag = sProcess.options.method.Value;
end


%% ===== GET OPTIONS =====
function OPTIONS = GetOptions(sProcess, sInput)
    % Time window
    if isfield(sProcess.options, 'baseline') && ~isempty(sProcess.options.baseline) && ~isempty(sProcess.options.baseline.Value) && iscell(sProcess.options.baseline.Value)
        OPTIONS.Baseline = sProcess.options.baseline.Value{1};
    else
        OPTIONS.Baseline = [];
    end
    % Get baseline indices
    if ~isempty(OPTIONS.Baseline) 
        OPTIONS.iBaseline = panel_time('GetTimeIndices', sInput.TimeVector, OPTIONS.Baseline);
        if isempty(OPTIONS.iBaseline)
            bst_report('Error', sProcess, [], 'Invalid baseline definition.');
            OPTIONS = [];
            return;
        end
    % Get all file
    else
        OPTIONS.iBaseline = 1:size(sInput.A,2);
    end
    
    % Sensor type
    if ismember(sInput(1).FileType, {'data'}) && isfield(sProcess.options, 'sensortypes') && ~isempty(sProcess.options.sensortypes) && ~isempty(sProcess.options.sensortypes.Value)
        OPTIONS.SensorTypes = sProcess.options.sensortypes.Value;
    else
        OPTIONS.SensorTypes = [];
    end
    % Method
    if isfield(sProcess.options, 'method') && ~isempty(sProcess.options.method) && ~isempty(sProcess.options.method.Value)
        OPTIONS.Method = sProcess.options.method.Value;
    else
        OPTIONS.Method = [];
    end
    % Absolute values
    if isfield(sProcess.options, 'source_abs') && ~isempty(sProcess.options.source_abs) && ~isempty(sProcess.options.source_abs.Value)
        OPTIONS.isAbsolute = sProcess.options.source_abs.Value;
    else
        OPTIONS.isAbsolute = 0;
    end
end
    

%% ===== RUN =====
function sInputB = Run(sProcess, sInputA, sInputB) %#ok<DEFNU>
    % Parse inputs
    if (nargin < 3) || isempty(sInputB)
        sInputB = sInputA;
    end
    % Get options
    OPTIONS = GetOptions(sProcess, sInputA);
    if isempty(OPTIONS)
        sInputB = [];
        return;
    end

    % Compute zscore
    sInputB.A = Compute(sInputB.A, sInputA.A(:,OPTIONS.iBaseline,:), OPTIONS.Method);
    % If there is a normalization: change data types
    if ismember(OPTIONS.Method, {'zscore', 'ersd', 'divmean', 'db', 'contrast'})
        if strcmpi(sInputB.FileType, 'timefreq')
            sInputB.Measure      = OPTIONS.Method;
            sInputB.ColormapType = 'stat2';
        elseif strcmpi(sInputB.FileType, 'results')
            sInputB.Function = OPTIONS.Method;
        end
    end
    % Change DataType (not for timefreq files, and not when just doing a DC correction)
    if ~strcmpi(sInputB.FileType, 'timefreq') && ~strcmpi(OPTIONS.Method, 'bl')
        sInputB.DataType = OPTIONS.Method;
    end
    % Change display units
    switch (OPTIONS.Method)
        case 'zscore',  sInputB.DisplayUnits = 'z';
        case 'ersd',    sInputB.DisplayUnits = '%';
        case 'db',      sInputB.DisplayUnits = 'dB';
    end
    % Add comment tag
    sInputB.CommentTag = OPTIONS.Method;
    % Do not keep the Std field in the output except for simple Baseline substraction
    if isfield(sInputB, 'Std') && ~isempty(sInputB.Std) && ~strcmpi(OPTIONS.Method, 'bl')
        sInputB.Std = [];
    end
end


%% ===== COMPUTE =====
% USAGE:  Fdata = process_baseline_norm('Compute', Fdata, Fbaseline, Method)
function Fdata = Compute(Fdata, Fbaseline, Method)   
    % Compute baseline statistics
    stdBaseline  = std(Fbaseline, 0, 2);
    meanBaseline = mean(Fbaseline, 2);
    % Remove null variance values
    stdBaseline(stdBaseline == 0) = 1e-12;
    
    % Normalization method
    switch (Method)
        case 'zscore'   % (x-mean)/std
            Fdata = bst_bsxfun(@minus,   Fdata, meanBaseline);
            Fdata = bst_bsxfun(@rdivide, Fdata, stdBaseline);
        case 'ersd'     % (x-mean)/mean*100
            Fdata = bst_bsxfun(@minus,   Fdata, meanBaseline);
            Fdata = bst_bsxfun(@rdivide, Fdata, meanBaseline) .* 100;
        case 'bl'       % (x-mean)
            Fdata = bst_bsxfun(@minus, Fdata, meanBaseline);
        case 'divmean'  % (x/mean)
            Fdata = bst_bsxfun(@rdivide, Fdata, meanBaseline);
        case 'db'       % 10*log10(x/mean)
            Fdata = 10 .* log10(abs(bst_bsxfun(@rdivide, Fdata, meanBaseline)));
        case 'contrast' % (x-mean)/(x+mean)
            Fnum  = bst_bsxfun(@minus,   Fdata, meanBaseline);
            Fdiv  = bst_bsxfun(@plus,    Fdata, meanBaseline);
            Fdata = bst_bsxfun(@rdivide, Fnum,  Fdiv);
        otherwise
            error(['Invalid normalization method: "' Method '"']);
    end
end


