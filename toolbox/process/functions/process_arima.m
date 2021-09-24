function varargout = process_arima( varargin )
% PROCESS_ARIMA: Auto-regressive Moving Average filter 
%
% USAGE:   sProcess = process_arima('GetDescription')
%            sInput = process_arima('Run', sProcess, sInput, method=[])
%                 F = process_arima('Compute', F, Fbase, Order)

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
% Authors: Francois Tadel, 2010-2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'ARIMA filter';
    sProcess.FileTag     = 'arima';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Pre-process';
    sProcess.Index       = 68;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'raw', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'raw', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.processDim  = 1;   % Process channel by channel
    
    % Definition of the options
    % === Baseline time window
    sProcess.options.baseline.Comment = 'Baseline:';
    sProcess.options.baseline.Type    = 'baseline';
    sProcess.options.baseline.Value   = [];
    % === Filter order
    sProcess.options.order.Comment = 'Order of the filter:';
    sProcess.options.order.Type    = 'value';
    sProcess.options.order.Value   = {5,'',0};
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data', 'raw'};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Order = sProcess.options.order.Value{1};
    if isfield(sProcess.options, 'baseline') && isfield(sProcess.options.baseline, 'Value') && iscell(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value{1})
        Time = sProcess.options.baseline.Value{1};
    else
        Time = [];
    end
    if isempty(Time)
        Comment = 'ARIMA(%d,1,0) - Baseline: [All file]';
    elseif any(abs(Time) > 2)
        Comment = sprintf('ARIMA(%d,1,0) - Baseline: [%1.3fs,%1.3fs]', Order, Time(1), Time(2));
    else
        Comment = sprintf('ARIMA(%d,1,0) - Baseline: [%dms,%dms]', Order, round(Time(1)*1000), round(Time(2)*1000));
    end
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Get options
    Order = sProcess.options.order.Value{1};
    if isfield(sProcess.options, 'baseline') && isfield(sProcess.options.baseline, 'Value') && iscell(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value{1})
        BaselineBounds = sProcess.options.baseline.Value{1};
    else
        BaselineBounds = [];
    end
    % Get baseline indices
    if ~isempty(BaselineBounds)
        iBaseline = panel_time('GetTimeIndices', sInput.TimeVector, BaselineBounds);
        if isempty(iBaseline)
            bst_report('Error', sProcess, [], 'Invalid baseline definition.');
            sInput = [];
            return;
        end
    % Get all file
    else
        iBaseline = 1:size(sInput.A,2);
    end
    % Filter data
    sInput.A = Compute(sInput.A, sInput.A(:,iBaseline), Order);
    % Error handling 
    if isempty(sInput.A)
        bst_report('Error', sProcess, [], 'Error while filtering the signal.');
        sInput = [];
        return;
    end
    % Do not keep the Std field in the output
    if isfield(sInput, 'Std') && ~isempty(sInput.Std)
        sInput.Std = [];
    end
end


%% ===== EXTERNAL CALL =====
% USAGE: process_arima('Compute', F, Fbase=[], Order=5)
function F = Compute(F, Fbase, Order)
    % Default order: 5
    if (nargin < 3) || isempty(Order)
        Order = 5;
    end
    % If there is no baseline, use the whole time segment
    if (nargin < 2) || isempty(Fbase)
        Fbase = F;
    end
    Nsig = size(F,1);
    
    % If order is 0, just diff the signal
    if (Order == 0)
        % Detrend and diff data to filter
        F = diff(detrend(F'))';
        % Add one sample at the beginning to account for the diff
        F = [F(:,2), F];
    else
        % Detrend and diff baseline
        Fbase = diff(detrend(Fbase'));
        % Compute AR model for each signal
        if bst_get('UseSigProcToolbox')
            arm = lpc(Fbase, Order);
        else
            arm = zeros(Nsig, Order+1);
            for i = 1:Nsig
                arm(i,:) = oc_lpc(Fbase(:,i), Order);
            end
        end
        % Remove the ones for each it cannot be estimated
        arm(any(isnan(arm),2),:) = [];
        % If there is nothing left, error
        if isempty(arm)
            F = [];
        end
        % Average all the models
        arm = mean(arm,1);

        % Detrend and diff data to filter
        F = diff(detrend(F'));
        % Add a few samples of mirrored signal at the beginning to minimize the edge effects
        F = [F(length(arm)+1:-1:1,:); F];
        % Apply filter to the data
        F = filter(arm, 1, F)';
        % Remove the mirrored samples (keep one, to account for the diff)
        F(:,1:length(arm)) = [];
    end
end



