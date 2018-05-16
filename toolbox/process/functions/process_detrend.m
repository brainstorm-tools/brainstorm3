function varargout = process_detrend( varargin )
% PROCES_DETREND: Remove a linear trend in a signal.
%
% USAGE:      sProcess = process_detrend('GetDescription')
%               sInput = process_detrend('Run', sProcess, sInput)
%                    x = process_detrend('Compute', F, iTime)

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
% Authors: Robert Oostenveld, 2008-2014  (Code inspired from the FieldTrip toolbox: ft_preproc_polyremoval.m)
%          Francois Tadel, 2014-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Remove linear trend';
    sProcess.FileTag     = 'detrend';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Pre-process';
    sProcess.Index       = 61;
    sProcess.Description = 'https://github.com/fieldtrip/fieldtrip/blob/master/preproc/ft_preproc_polyremoval.m';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data', 'results', 'matrix'};
    sProcess.OutputTypes = {'raw', 'data', 'results', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Default values for some options
    sProcess.processDim  = 1;    % Process channel by channel

    % Definition of the options
    % === Estimation time window
    sProcess.options.timewindow.Comment = 'Trend estimation:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data', 'raw'};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Get baseline
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value)
        TimeBounds = sProcess.options.timewindow.Value{1};
    else
        TimeBounds = [];
    end
    % Comment: seconds or miliseconds
    if isempty(TimeBounds)
        Comment = [sProcess.Comment, ': All file'];
    elseif any(abs(TimeBounds) > 2)
        Comment = sprintf('%s: [%1.3fs,%1.3fs]', sProcess.Comment, TimeBounds(1), TimeBounds(2));
    else
        Comment = sprintf('%s: [%dms,%dms]', sProcess.Comment, round(TimeBounds(1)*1000), round(TimeBounds(2)*1000));
    end
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Get options
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value)
        TimeBounds = sProcess.options.timewindow.Value{1};
    else
        TimeBounds = [];
    end
    % Get inputs
    if ~isempty(TimeBounds)
        iTime = panel_time('GetTimeIndices', sInput.TimeVector, TimeBounds);
        if isempty(iTime)
            bst_report('Error', sProcess, [], 'Invalid time definition.');
            sInput = [];
            return;
        end
    else
        iTime = [];
    end

    % Detrend signal
    sInput.A = Compute(sInput.A, iTime);
    
    % Do not keep the Std field in the output
    if isfield(sInput, 'Std') && ~isempty(sInput.Std)
        sInput.Std = [];
    end
end


%% ===== COMPUTE =====
% USAGE:  x = process_detrend('Compute', F, iTime=[])
function F = Compute(F, iTime)
    % Number of samples
    nTime = size(F,2);
    % Parse inputs
    if (nargin < 2) || isempty(iTime)
        iTime = 1:nTime;
    end
    % Basis functions
    x = [ones(1,nTime); 0:nTime-1];
    % Estimate the contribution of the basis functions
    % beta = dat(:,iTime)/x(:,iTime); <-this leads to numerical issues, even in simple examples
    invxcov = inv(x(:,iTime) * x(:,iTime)');
    beta    = F(:,iTime) * x(:,iTime)' * invxcov;
    % Remove the estimated basis functions
    F = F - beta*x;
end




